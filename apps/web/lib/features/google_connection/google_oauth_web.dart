// GIS external JavaScript field names must match the Google API.
// ignore_for_file: non_constant_identifier_names
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'google_oauth.dart';

@JS('globalThis.google')
external _Google? get _google;
extension type _Google(JSObject _) implements JSObject {
  external _Accounts get accounts;
}
extension type _Accounts(JSObject _) implements JSObject {
  external _OAuth get oauth2;
}
extension type _OAuth(JSObject _) implements JSObject {
  external _TokenClient initTokenClient(_TokenConfig config);
  external void revoke(String token, JSFunction callback);
}
extension type _TokenClient(JSObject _) implements JSObject {
  external void requestAccessToken(_TokenRequest request);
}
extension type _TokenRequest._(JSObject _) implements JSObject {
  external factory _TokenRequest({String prompt});
}
extension type _TokenConfig._(JSObject _) implements JSObject {
  external factory _TokenConfig(
      {String client_id,
      String scope,
      bool include_granted_scopes,
      JSFunction callback,
      JSFunction error_callback});
}
extension type _TokenResponse(JSObject _) implements JSObject {
  external String? get access_token;
  external JSAny? get expires_in;
  external String? get error;
  external String? get scope;
}

extension type _RevocationResponse(JSObject _) implements JSObject {
  external bool? get successful;
}

GoogleOAuthPort createGoogleOAuth(String clientId) => _WebOAuth(clientId);

class _WebOAuth implements GoogleOAuthPort {
  _WebOAuth(this.clientId);
  final String clientId;
  Future<void>? _initialization;
  @override
  Future<void> initialize() => _initialization ??= _load();
  Future<void> _load() async {
    if (_google != null) return;
    final done = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = 'https://accounts.google.com/gsi/client'
      ..async = true;
    script.onload = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    script.onerror = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(const ConnectionFailure(
            'Google 로그인 모듈을 불러오지 못했어요. 네트워크를 확인해 주세요.'));
      }
    }).toJS;
    web.document.head!.append(script);
    try {
      await done.future.timeout(const Duration(seconds: 20));
      if (_google == null) {
        throw const ConnectionFailure('Google 로그인 모듈이 준비되지 않았어요.');
      }
    } catch (_) {
      script.remove();
      _initialization = null;
      rethrow;
    }
  }

  @override
  Future<OAuthGrant> authorize(String scope) {
    // No asynchronous work before requestAccessToken: preserve the user gesture
    // for Safari popup handling. initialize() runs before enabling the button.
    final oauth = _google?.accounts.oauth2;
    if (oauth == null) {
      return Future.error(const ConnectionFailure('로그인 모듈을 먼저 준비해 주세요.'));
    }
    final done = Completer<OAuthGrant>();
    void fail(String message) {
      if (!done.isCompleted) done.completeError(ConnectionFailure(message));
    }

    final client = oauth.initTokenClient(_TokenConfig(
      client_id: clientId,
      scope: scope,
      include_granted_scopes: true,
      callback: ((_TokenResponse result) {
        if (done.isCompleted) return;
        final token = result.access_token;
        final granted = (result.scope ?? '').split(' ').toSet();
        final required =
            scope.split(' ').where((s) => s.startsWith('https://'));
        if (result.error != null ||
            token == null ||
            token.isEmpty ||
            !required.every(granted.contains)) {
          fail('필요한 Google 권한에 동의하지 않았어요.');
          return;
        }
        final seconds =
            num.tryParse('${result.expires_in.dartify()}')?.toInt() ?? 0;
        if (seconds < 60) {
          fail('유효한 인증 시간을 확인하지 못했어요.');
          return;
        }
        done.complete(
            OAuthGrant(token, DateTime.now().add(Duration(seconds: seconds))));
      }).toJS,
      error_callback: ((JSObject _) {
        fail('로그인 창이 닫혔거나 열리지 않았어요. 팝업 설정을 확인해 주세요.');
      }).toJS,
    ));
    client.requestAccessToken(_TokenRequest(prompt: 'consent'));
    return done.future.timeout(const Duration(minutes: 1), onTimeout: () {
      fail('로그인 시간이 초과됐어요. 다시 시도해 주세요.');
      throw const ConnectionFailure('로그인 시간이 초과됐어요. 다시 시도해 주세요.');
    });
  }

  @override
  Future<void> revoke(String accessToken) async {
    final oauth = _google?.accounts.oauth2;
    if (oauth == null) return;
    final done = Completer<void>();
    oauth.revoke(
        accessToken,
        ((_RevocationResponse response) {
          if (done.isCompleted) {
            return;
          }
          if (response.successful == true) {
            done.complete();
          } else {
            done.completeError(
                const ConnectionFailure('Google 권한 철회를 확인하지 못했어요.'));
          }
        }).toJS);
    await done.future.timeout(const Duration(seconds: 5));
  }
}
