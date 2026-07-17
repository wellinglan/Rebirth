from __future__ import annotations

import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, text


SERVER_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = SERVER_ROOT.parent
FIXTURE = REPOSITORY_ROOT / "test" / "fixtures" / "ai_weekly_input_v1.json"
EXPECTED_HASH = (
    REPOSITORY_ROOT / "test" / "fixtures" / "ai_weekly_input_v1_expected_hash.txt"
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify Fake AI claims through multiple Uvicorn workers."
    )
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--port", type=int, default=8018)
    parser.add_argument(
        "--database-url",
        default=os.getenv("REBIRTH_POSTGRES_TEST_URL"),
    )
    args = parser.parse_args()
    if args.workers < 2:
        parser.error("--workers must be at least 2")
    if not args.database_url:
        parser.error("--database-url or REBIRTH_POSTGRES_TEST_URL is required")
    _require_free_port(args.port)

    environment = os.environ.copy()
    environment.update(
        {
            "REBIRTH_ENV": "development",
            "REBIRTH_DATABASE_URL": args.database_url,
            "REBIRTH_JWT_SECRET": "multiworker-verification-only-secret",
            "REBIRTH_AI_PROVIDER": "fake",
            "REBIRTH_AI_FAKE_SCENARIO": "success",
        }
    )
    os.environ["REBIRTH_DATABASE_URL"] = args.database_url
    command.upgrade(Config(str(SERVER_ROOT / "alembic.ini")), "head")

    command_line = [
        sys.executable,
        "-m",
        "uvicorn",
        "app.main:app",
        "--host",
        "127.0.0.1",
        "--port",
        str(args.port),
        "--workers",
        str(args.workers),
    ]
    creation_flags = (
        subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    )
    process = subprocess.Popen(
        command_line,
        cwd=SERVER_ROOT,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        creationflags=creation_flags,
    )
    logs: list[str] = []
    reader = threading.Thread(target=_collect_output, args=(process, logs), daemon=True)
    reader.start()
    base_url = f"http://127.0.0.1:{args.port}"
    try:
        _wait_for_health(base_url, process)
        with httpx.Client(base_url=base_url, timeout=20) as client:
            login = client.post(
                "/auth/dev-login",
                json={"dev_user_key": f"multiworker-{uuid.uuid4()}"},
            )
            login.raise_for_status()
            headers = {
                "Authorization": f"Bearer {login.json()['access_token']}"
            }
        request_id = str(uuid.uuid4())
        body = {
            "request_id": request_id,
            "input_hash": EXPECTED_HASH.read_text(encoding="utf-8").strip(),
            "payload": json.loads(FIXTURE.read_text(encoding="utf-8")),
        }

        def send() -> tuple[int, dict[str, object]]:
            response = httpx.post(
                f"{base_url}/ai/reports/weekly/generate",
                headers=headers,
                json=body,
                timeout=20,
            )
            return response.status_code, response.json()

        with ThreadPoolExecutor(max_workers=8) as executor:
            responses = list(executor.map(lambda _: send(), range(8)))
        if any(status not in {200, 202} for status, _ in responses):
            raise RuntimeError("Unexpected multi-worker response status.")
        final = httpx.get(
            f"{base_url}/ai/requests/{request_id}", headers=headers, timeout=20
        )
        final.raise_for_status()
        final_body = final.json()
        if final_body["status"] != "completed":
            raise RuntimeError("The multi-worker request did not complete.")

        engine = create_engine(args.database_url)
        try:
            with engine.connect() as connection:
                row_count = connection.scalar(
                    text(
                        "SELECT count(*) FROM ai_generation_requests "
                        "WHERE request_id=:request_id"
                    ),
                    {"request_id": request_id},
                )
                postgres_version = connection.scalar(text("SHOW server_version"))
        finally:
            engine.dispose()
        time.sleep(0.2)
        provider_started = sum(
            1
            for line in logs
            if "ai_provider_started" in line and request_id in line
        )
        if row_count != 1 or provider_started != 1:
            raise RuntimeError("Multi-worker claim ownership verification failed.")
        print(
            json.dumps(
                {
                    "workers": args.workers,
                    "request_count": len(responses),
                    "response_statuses": sorted(status for status, _ in responses),
                    "final_status": final_body["status"],
                    "ledger_row_count": row_count,
                    "provider_call_started_count": provider_started,
                    "postgres_version": postgres_version,
                },
                sort_keys=True,
            )
        )
        return 0
    finally:
        _stop_process_tree(process)
        reader.join(timeout=2)


def _collect_output(process: subprocess.Popen[str], lines: list[str]) -> None:
    if process.stdout is None:
        return
    for line in process.stdout:
        lines.append(line.rstrip())


def _wait_for_health(base_url: str, process: subprocess.Popen[str]) -> None:
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("Uvicorn exited before becoming healthy.")
        try:
            with urllib.request.urlopen(f"{base_url}/health", timeout=1) as response:
                if response.status == 200:
                    return
        except OSError:
            time.sleep(0.25)
    raise RuntimeError("Uvicorn did not become healthy in time.")


def _require_free_port(port: int) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as connection:
        connection.settimeout(0.2)
        if connection.connect_ex(("127.0.0.1", port)) == 0:
            raise RuntimeError(f"Verification port {port} is already in use.")


def _stop_process_tree(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        process.send_signal(signal.CTRL_BREAK_EVENT)
    else:
        process.terminate()
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                check=False,
                capture_output=True,
                text=True,
            )
        else:
            process.kill()
        process.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
