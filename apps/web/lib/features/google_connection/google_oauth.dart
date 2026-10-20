/// Public web OAuth client ID; this is not a client secret.
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const identityScope = 'openid email profile';
const sheetsScope = 'https://www.googleapis.com/auth/spreadsheets';

class ConnectionFailure implements Exception {
  const ConnectionFailure(this.message,
      {this.reauthenticate = false, this.uncertainWrite = false});
  final String message;
  final bool reauthenticate;
  final bool uncertainWrite;
  @override
  String toString() => message;
}

class OAuthGrant {
  const OAuthGrant(this.accessToken, this.expiresAt);
  final String accessToken;
  final DateTime expiresAt;
  bool validAt(DateTime now) =>
      now.isBefore(expiresAt.subtract(const Duration(seconds: 30)));
}

abstract interface class GoogleOAuthPort {
  Future<void> initialize();
  Future<OAuthGrant> authorize(String scope);
  Future<void> revoke(String accessToken);
}
