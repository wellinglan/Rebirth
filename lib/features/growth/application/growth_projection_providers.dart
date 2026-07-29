import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/growth/data/contributors/focus_growth_contributor.dart';
import 'package:rebirth/features/growth/data/contributors/recovery_growth_contributor.dart';
import 'package:rebirth/features/growth/data/contributors/reflection_growth_contributor.dart';
import 'package:rebirth/features/growth/data/contributors/subjective_state_growth_contributor.dart';

import 'growth_dimension_contributor_registry.dart';
import 'growth_projection_engine.dart';

final growthDimensionContributorRegistryProvider =
    Provider<GrowthDimensionContributorRegistry>((ref) {
      return GrowthDimensionContributorRegistry([
        FocusGrowthContributor(),
        RecoveryGrowthContributor(),
        SubjectiveStateGrowthContributor(),
        ReflectionGrowthContributor(),
      ]);
    });

final growthProjectionEngineProvider = Provider<GrowthProjectionEngine>((ref) {
  return GrowthProjectionEngine(
    ref.watch(growthDimensionContributorRegistryProvider),
  );
});
