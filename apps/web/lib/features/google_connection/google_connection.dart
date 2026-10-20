import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'google_oauth.dart';
import 'google_oauth_factory.dart';
import 'sheets_probe.dart';

class GoogleProfile {
  const GoogleProfile(this.subject, this.email, this.name);
  final String subject;
  final String email;
  final String name;
}

final googleConnectionProvider =
    ChangeNotifierProvider<GoogleConnection>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return GoogleConnection(
      createGoogleOAuth(googleWebClientId), GoogleApi(client),
      configured: googleWebClientId.isNotEmpty);
});

class GoogleConnection extends ChangeNotifier {
  GoogleConnection(this.oauth, this.api,
      {required this.configured, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final GoogleOAuthPort oauth;
  final GoogleApi api;
  final bool configured;
  final DateTime Function() clock;
  OAuthGrant? _identityGrant;
  OAuthGrant? _sheetGrant;
  GoogleProfile? profile;
  SheetInspection? inspection;
  String? createdSheetId;
  String? error;
  bool ready = false;
  bool busy = false;
  bool _disposed = false;
  bool get sheetsAuthorized => _sheetGrant?.validAt(clock()) ?? false;

  Future<void> initialize() => _run(() async {
        if (!configured) return;
        await oauth.initialize();
        ready = true;
      });
  Future<void> signIn() => _run(() async {
        if (!ready) throw const ConnectionFailure('로그인 모듈을 먼저 준비해 주세요.');
        final grant = await oauth.authorize(identityScope);
        final user = await api.request(
            grant.accessToken, 'openidconnect.googleapis.com', '/v1/userinfo');
        if (user['sub'] is! String ||
            (user['sub'] as String).isEmpty ||
            user['email_verified'] != true ||
            user['email'] is! String) {
          throw const ConnectionFailure('확인된 Google 계정 정보를 가져오지 못했어요.');
        }
        _identityGrant = grant;
        _sheetGrant = null;
        inspection = null;
        createdSheetId = null;
        profile = GoogleProfile(user['sub'] as String, user['email'] as String,
            (user['name'] as String?) ?? user['email'] as String);
      });
  Future<void> authorizeSheets() => _run(() async {
        if (profile == null) {
          throw const ConnectionFailure('먼저 Google 로그인해 주세요.');
        }
        final grant = await oauth.authorize('$identityScope $sheetsScope');
        final user = await api.request(
            grant.accessToken, 'openidconnect.googleapis.com', '/v1/userinfo');
        if (user['sub'] != profile!.subject) {
          throw const ConnectionFailure(
              '로그인한 계정과 다른 계정을 선택했어요. 같은 Google 계정으로 권한을 승인해 주세요.');
        }
        _sheetGrant = grant;
      });
  String _token() {
    final grant = _sheetGrant;
    if (grant == null || !grant.validAt(clock())) {
      _sheetGrant = null;
      throw const ConnectionFailure('Sheets 권한이 없거나 만료됐어요. 다시 동의해 주세요.');
    }
    return grant.accessToken;
  }

  Future<void> inspect(String input) => _run(() async {
        inspection = null;
        inspection = await SheetsProbe(api).inspect(_token(), input);
      });
  Future<void> createProbe() => _run(() async {
        inspection = null;
        if (profile == null) throw const ConnectionFailure('먼저 로그인해 주세요.');
        inspection = await SheetsProbe(api)
            .createAndVerify(_token(), profile!.subject, onCreated: (id) {
          createdSheetId = id;
        });
      });
  Future<void> disconnect() => _run(() async {
        final token = _sheetGrant?.accessToken ?? _identityGrant?.accessToken;
        profile = null;
        _identityGrant = null;
        _sheetGrant = null;
        inspection = null;
        createdSheetId = null;
        if (token != null) {
          try {
            await oauth.revoke(token);
          } catch (_) {
            throw const ConnectionFailure(
                '로컬 연결은 해제했지만 Google 권한 철회는 확인하지 못했어요. Google 계정의 연결된 앱을 확인해 주세요.');
          }
        }
      });
  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on ConnectionFailure catch (failure) {
      if (failure.reauthenticate) {
        _identityGrant = null;
        _sheetGrant = null;
        profile = null;
      }
      error = failure.message;
    } catch (_) {
      error =
          '요청을 완료하지 못했어요. 네트워크와 설정을 확인해 주세요. 쓰기 작업은 반영됐을 수 있으니 생성한 시트를 먼저 확인해 주세요.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _identityGrant = null;
    _sheetGrant = null;
    super.dispose();
  }
}
