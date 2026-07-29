enum PersonalDataSensitivity { standardPrivate, sensitive, highlySensitive }

extension PersonalDataSensitivityRules on PersonalDataSensitivity {
  bool isAtLeast(PersonalDataSensitivity minimum) => index >= minimum.index;

  PersonalDataSensitivity elevatedWith(PersonalDataSensitivity other) {
    return index >= other.index ? this : other;
  }

  String get displayLabel => switch (this) {
    PersonalDataSensitivity.standardPrivate => '本地私密',
    PersonalDataSensitivity.sensitive => '敏感',
    PersonalDataSensitivity.highlySensitive => '高度敏感',
  };
}
