from __future__ import annotations


class AiGatewayError(Exception):
    def __init__(self, code: str, *, status_code: int = 502) -> None:
        super().__init__(code)
        self.code = code
        self.status_code = status_code


class GatewayDisabledError(AiGatewayError):
    def __init__(self) -> None:
        super().__init__("gateway_disabled", status_code=503)


class InputHashMismatchError(AiGatewayError):
    def __init__(self) -> None:
        super().__init__("input_hash_mismatch", status_code=422)


class UnsupportedContractError(AiGatewayError):
    def __init__(self, code: str) -> None:
        super().__init__(code, status_code=422)


class IdempotencyConflictError(AiGatewayError):
    def __init__(self) -> None:
        super().__init__("idempotency_conflict", status_code=409)
