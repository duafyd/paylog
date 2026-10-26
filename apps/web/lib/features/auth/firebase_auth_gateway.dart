import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'auth_port.dart';
import 'firebase_options.dart';
import 'username.dart';

class FirebaseAuthGateway implements AuthPort {
  FirebaseAuth? _auth;
  Future<FirebaseAuth>? _initialization;

  AuthIdentity? _identity(User? user) {
    if (user == null) return null;
    final username = usernameFromAddress(user.email);
    if (username == null ||
        !user.providerData.any((p) => p.providerId == 'password')) {
      return null;
    }
    return AuthIdentity(uid: user.uid, username: username);
  }

  @override
  Future<AuthIdentity?> initialize() async {
    final auth = await (_initialization ??= _initializeAuth());
    final user = await auth.authStateChanges().first;
    final identity = _identity(user);
    // Do not restore the previous Google-only session into username login.
    if (user != null && identity == null) await auth.signOut();
    return identity;
  }

  Future<FirebaseAuth> _initializeAuth() async {
    try {
      if (!kIsWeb) throw const AuthFailure('unsupported-platform');
      final app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: activeFirebaseOptions)
          : Firebase.app();
      if (app.options.projectId != activeFirebaseOptions.projectId ||
          app.options.appId != activeFirebaseOptions.appId) {
        throw const AuthFailure('wrong-project');
      }
      _auth = FirebaseAuth.instanceFor(app: app);
      if (useFirebaseEmulators) {
        await _auth!
            .useAuthEmulator('127.0.0.1', 9099, automaticHostMapping: false);
      }
      // Keep refresh across this tab's lifetime without permanent login storage.
      await _auth!.setPersistence(Persistence.SESSION);
      return _auth!;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  @override
  Stream<AuthIdentity?> get changes => _auth!.authStateChanges().map(_identity);

  @override
  Future<AuthIdentity> signIn(String username, String password) =>
      _authenticate(username, password, creating: false);

  @override
  Future<AuthIdentity> register(String username, String password) =>
      _authenticate(username, password, creating: true);

  Future<AuthIdentity> _authenticate(String username, String password,
      {required bool creating}) async {
    final address = usernameAddress(username);
    validatePassword(password, creating: creating);
    try {
      final result = creating
          ? await _auth!.createUserWithEmailAndPassword(
              email: address, password: password)
          : await _auth!
              .signInWithEmailAndPassword(email: address, password: password);
      final identity = _identity(result.user);
      if (identity == null) throw const AuthFailure('missing-user');
      return identity;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth!.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code);
    }
  }
}
