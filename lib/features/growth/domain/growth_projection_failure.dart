import 'growth_identifier.dart';

final class GrowthProjectionFailure {
  const GrowthProjectionFailure({
    required this.dimensionId,
    required this.reasonCode,
    required this.message,
  });

  final GrowthDimensionId dimensionId;
  final String reasonCode;
  final String message;
}
