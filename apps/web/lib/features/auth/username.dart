import 'auth_port.dart';

/// Reserved, non-deliverable namespace for Firebase's email/password API.
/// The username is the complete login identifier; no user email is collected.
const usernameDomain = 'accounts.paylog.invalid';

String normalizeUsername(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-z][a-z0-9_]{3,19}$').hasMatch(normalized)) {
    throw const AuthFailure('invalid-username');
  }
  return normalized;
}

String usernameAddress(String value) =>
    '${normalizeUsername(value)}@$usernameDomain';

String? usernameFromAddress(String? address) {
  if (address == null || !address.endsWith('@$usernameDomain')) return null;
  final value =
      address.substring(0, address.length - usernameDomain.length - 1);
  try {
    return normalizeUsername(value);
  } on AuthFailure {
    return null;
  }
}

void validatePassword(String value, {required bool creating}) {
  if (value.isEmpty || value.length > 128) {
    throw const AuthFailure('invalid-password');
  }
  if (creating && (value.length < 8 || value.trim().isEmpty)) {
    throw const AuthFailure('weak-password');
  }
}
