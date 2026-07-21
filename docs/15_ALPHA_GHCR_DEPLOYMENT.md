# Alpha GHCR Deployment

## Purpose

Rebirth Cloud Alpha images are built and published by GitHub Actions. The Windows development machine does not need Docker and does not participate in image builds.

The `Publish Alpha Images` workflow publishes:

- `ghcr.io/wellinglan/rebirth-api:<full-commit-sha>`;
- `ghcr.io/wellinglan/rebirth-api:<8-character-short-sha>`;
- `ghcr.io/wellinglan/rebirth-api:alpha-latest` for `main` only;
- `ghcr.io/wellinglan/rebirth-postgres:17-alpine`.

The API image uses `server` as its Docker build context and `server/Dockerfile`. The PostgreSQL image is pulled as `postgres:17-alpine`, tagged, and pushed without changing its contents or introducing another Dockerfile.

## Credentials

GitHub Actions publishes with its automatically provided `GITHUB_TOKEN` and workflow permissions limited to `contents: read` and `packages: write`. No user-managed publishing PAT is used by CI.

The Beijing Alpha server pulls only from GHCR. Log in there with a dedicated credential that has only `read:packages`, then use `docker compose pull` and restart the services according to the server deployment configuration. Do not reuse the workflow `GITHUB_TOKEN`; it exists only during a GitHub Actions run.

Never commit a GitHub PAT, JWT secret, PostgreSQL password, `.env` file, or Docker registry password. Server runtime secrets stay in the server environment and are not baked into either image.

## Current Boundary

This remains a Development deployment using the Fake Provider over a Tailscale private network. It is a private Cloud Alpha debug environment, not a production deployment, and it does not expose a public API.

The Beijing server does not pull `python:3.12-slim` or `postgres:17-alpine` directly from Docker Hub. GitHub-hosted Ubuntu runners perform those Docker Hub pulls while building or mirroring, and the server consumes the resulting GHCR images.
