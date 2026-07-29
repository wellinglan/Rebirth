import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';

import 'growth_dimension_descriptor.dart';
import 'growth_dimension_projection.dart';
import 'growth_projection_context.dart';

abstract interface class GrowthDimensionContributor {
  GrowthDimensionDescriptor get descriptor;

  Set<PersonalDataCapability> get requiredCapabilities;

  GrowthDimensionProjection project(
    PersonalDataAggregationResult result,
    GrowthProjectionContext context,
  );
}
