import '../domain/personal_data_aggregation_result.dart';

final class PersonalDataOverviewState {
  const PersonalDataOverviewState({
    required this.selectedDate,
    required this.todayDate,
    required this.result,
    required this.isRefreshing,
    this.errorMessage,
  });

  final String selectedDate;
  final String todayDate;
  final PersonalDataAggregationResult? result;
  final bool isRefreshing;
  final String? errorMessage;

  bool get isToday => selectedDate == todayDate;

  PersonalDataOverviewState copyWith({
    String? selectedDate,
    String? todayDate,
    PersonalDataAggregationResult? result,
    bool clearResult = false,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PersonalDataOverviewState(
      selectedDate: selectedDate ?? this.selectedDate,
      todayDate: todayDate ?? this.todayDate,
      result: clearResult ? null : result ?? this.result,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
