import 'google_oauth.dart';

GoogleOAuthPort createGoogleOAuth(String clientId) => _UnsupportedOAuth();

class _UnsupportedOAuth implements GoogleOAuthPort {
  @override
  Future<void> initialize() async =>
      throw const ConnectionFailure('Google 연결은 웹 브라우저에서 지원합니다.');
  @override
  Future<OAuthGrant> authorize(String scope) async =>
      throw const ConnectionFailure('웹 브라우저에서 실행해 주세요.');
  @override
  Future<void> revoke(String accessToken) async {}
}
