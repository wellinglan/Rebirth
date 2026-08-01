enum AiReportStatus {
  pending('pending'),
  completed('completed'),
  failed('failed');

  const AiReportStatus(this.databaseValue);

  final String databaseValue;

  static AiReportStatus fromDatabaseValue(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => throw ArgumentError.value(value, 'value'),
    );
  }
}

enum AiReportFailureCode {
  aiDisabled('ai_disabled'),
  gatewayDisabled('gateway_disabled'),
  usageLimitReached('usage_limit_reached'),
  authenticationRequired('authentication_required'),
  invalidRequest('invalid_request'),
  invalidInput('invalid_input'),
  inputHashMismatch('input_hash_mismatch'),
  unsupportedReportType('unsupported_report_type'),
  unsupportedPromptVersion('unsupported_prompt_version'),
  unsupportedScope('unsupported_scope'),
  providerAuthenticationFailed('provider_authentication_failed'),
  providerAuthFailed('provider_auth_failed'),
  providerRateLimited('provider_rate_limited'),
  providerTimeout('provider_timeout'),
  providerUnavailable('provider_unavailable'),
  providerRefused('provider_refused'),
  requestFailed('request_failed'),
  responseInvalid('response_invalid'),
  idempotencyConflict('idempotency_conflict'),
  outcomeUnknown('outcome_unknown'),
  resultExpired('result_expired'),
  serverStateNotFound('server_state_not_found'),
  requestBindingFailed('request_binding_failed'),
  networkOutcomeUnknown('network_outcome_unknown'),
  cancelled('cancelled'),
  unknown('unknown');

  const AiReportFailureCode(this.databaseValue);

  final String databaseValue;

  static bool isSupported(String value) {
    return values.any((code) => code.databaseValue == value);
  }
}
