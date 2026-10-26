import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../google_connection/google_connection.dart';
import '../transactions/transaction_repository.dart';
import 'auth_port.dart';
import 'firebase_auth_gateway.dart';
import 'username.dart';

final firebaseAuthPortProvider =
    Provider<AuthPort>((ref) => FirebaseAuthGateway());
final firebaseSessionProvider = ChangeNotifierProvider<AuthSession>((ref) {
  final session =
      AuthSession(ref.watch(firebaseAuthPortProvider), onIdentityChanged: () {
    ref.read(googleConnectionProvider).invalidateSession();
    ref.read(activeRepositoryProvider.notifier).state = null;
    ref.invalidate(demoRepositoryProvider);
  });
  scheduleMicrotask(session.initialize);
  return session;
});

class AuthSession extends ChangeNotifier {
  AuthSession(this.port,
      {this.onIdentityChanged,
      this.initializationTimeout = const Duration(seconds: 20)});
  final AuthPort port;
  final Duration initializationTimeout;
  final VoidCallback? onIdentityChanged;
  StreamSubscription<AuthIdentity?>? _subscription;
  AuthIdentity? user;
  bool ready = false;
  bool busy = false;
  String? error;
  bool _disposed = false;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _setUser(AuthIdentity? identity) {
    if (_disposed) return;
    if (user?.uid != identity?.uid) onIdentityChanged?.call();
    user = identity;
    _publish();
  }

  Future<void> initialize() async {
    if (busy || ready || _disposed) return;
    busy = true;
    error = null;
    _publish();
    try {
      final identity = await port.initialize().timeout(initializationTimeout);
      if (_disposed) return;
      _setUser(identity);
      _subscription = port.changes.listen(_setUser, onError: (Object _) {
        if (_disposed) return;
        ready = false;
        _setUser(null);
        unawaited(_subscription?.cancel());
        _subscription = null;
        error = '로그인 상태를 확인하지 못했어요. 다시 준비한 뒤 로그인해 주세요.';
        _publish();
      });
      ready = true;
    } catch (failure) {
      error = failure is AuthFailure
          ? authErrorMessage(failure.code)
          : '로그인을 준비하지 못했어요. 네트워크를 확인하고 다시 시도해 주세요.';
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<void> signIn(String username, String password) =>
      _authenticate(username, password, creating: false);

  Future<void> register(String username, String password) =>
      _authenticate(username, password, creating: true);

  Future<void> _authenticate(String username, String password,
      {required bool creating}) async {
    if (!ready || busy || _disposed) return;
    busy = true;
    error = null;
    _publish();
    try {
      final normalized = normalizeUsername(username);
      validatePassword(password, creating: creating);
      final identity = creating
          ? await port.register(normalized, password)
          : await port.signIn(normalized, password);
      _setUser(identity);
    } catch (failure) {
      if (!_disposed) {
        error = failure is AuthFailure
            ? authErrorMessage(failure.code)
            : '요청을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.';
      }
    } finally {
      busy = false;
      _publish();
    }
  }

  void clearError() {
    error = null;
    _publish();
  }

  Future<void> signOut() async {
    if (!ready || busy || _disposed) return;
    busy = true;
    error = null;
    _publish();
    try {
      await port.signOut();
      _setUser(null);
    } catch (_) {
      if (!_disposed) error = '로그아웃하지 못했어요. 다시 시도해 주세요.';
    } finally {
      busy = false;
      _publish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

String authErrorMessage(String code) => switch (code) {
      'invalid-username' => '아이디는 영문으로 시작하는 영문·숫자·밑줄 4~20자로 입력해 주세요.',
      'invalid-password' => '비밀번호를 입력해 주세요. 최대 128자까지 사용할 수 있어요.',
      'weak-password' ||
      'password-does-not-meet-requirements' =>
        '비밀번호는 8~128자로 입력해 주세요. 추가 조건이 안내되면 함께 확인해 주세요.',
      'email-already-in-use' => '이미 사용 중인 아이디예요. 다른 아이디를 입력해 주세요.',
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' ||
      'invalid-login-credentials' =>
        '아이디 또는 비밀번호를 확인해 주세요.',
      'operation-not-allowed' => '회원가입·로그인이 아직 준비되지 않았어요. 사이트 운영자에게 알려 주세요.',
      'network-request-failed' => '네트워크 연결을 확인하고 다시 시도해 주세요.',
      'too-many-requests' => '요청이 많아 잠시 쉬고 있어요. 잠시 후 다시 시도해 주세요.',
      'user-disabled' => '사용이 중지된 계정이에요. 사이트 운영자에게 문의해 주세요.',
      'unsupported-platform' => 'Safari 또는 Chrome에서 웹앱을 열어 주세요.',
      'wrong-project' => '로그인 설정을 확인해야 해요. 사이트 운영자에게 알려 주세요.',
      _ => '요청을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.',
    };
