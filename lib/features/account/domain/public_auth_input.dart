final class PublicAuthInput {
  static const usernameMinLength = 4;
  static const usernameMaxLength = 64;
  static const passwordMinLength = 12;
  static const passwordMaxLength = 128;
  static const displayNameMaxLength = 128;

  static final RegExp _usernamePattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]*$',
  );
  static final RegExp _controlCharacters = RegExp(
    r'[\u0000-\u001F\u007F-\u009F]',
  );

  const PublicAuthInput._();

  static String normalizeUsername(String value) => value.toLowerCase();

  static String? usernameError(String? value) {
    if (value == null || value.isEmpty) return '请输入用户名';
    if (value != value.trim() ||
        value.length < usernameMinLength ||
        value.length > usernameMaxLength ||
        !_usernamePattern.hasMatch(value)) {
      return '请输入 4–64 位用户名，可使用字母、数字、点、下划线或连字符';
    }
    return null;
  }

  static String? loginPasswordError(String? value) {
    if (value == null || value.isEmpty) return '请输入密码';
    if (_unicodeLength(value) > passwordMaxLength) return '密码长度不能超过 128 个字符';
    return null;
  }

  static String? registrationPasswordError(String? value) {
    if (value == null || value.isEmpty) return '请输入密码';
    final length = _unicodeLength(value);
    if (length < passwordMinLength || length > passwordMaxLength) {
      return '密码需为 12–128 个字符';
    }
    if (_controlCharacters.hasMatch(value)) return '密码不能包含控制字符';
    return null;
  }

  static String? confirmationPasswordError(String? value, String password) {
    if (value == null || value.isEmpty) return '请再次输入密码';
    if (value != password) return '两次输入的密码不一致';
    return null;
  }

  static String? displayNameError(String? value) {
    if (value == null || value.isEmpty) return null;
    if (_unicodeLength(value.trim()) > displayNameMaxLength) {
      return '显示名称不能超过 128 个字符';
    }
    return null;
  }

  static String? normalizeDisplayName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _unicodeLength(String value) => value.runes.length;
}
