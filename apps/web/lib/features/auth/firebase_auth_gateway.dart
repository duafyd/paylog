import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'auth_port.dart';
import 'firebase_options.dart';

class FirebaseAuthGateway implements AuthPort {
  FirebaseAuth? _auth;
  Future<FirebaseAuth>? _initialization;

  AuthIdentity? _identity(User? user) => user == null
      ? null
      : AuthIdentity(uid: user.uid, email: user.email, name: user.displayName);

  @override
  Future<AuthIdentity?> initialize() async {
    final auth = await (_initialization ??= _initializeAuth());
    return _identity(await auth.authStateChanges().first);
  }

  Future<FirebaseAuth> _initializeAuth() async {
    try {
      if (!kIsWeb) throw const AuthFailure('unsupported-platform');
      final app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: paylogFirebaseWebOptions)
          : Firebase.app();
      if (app.options.projectId != paylogFirebaseWebOptions.projectId ||
          app.options.appId != paylogFirebaseWebOptions.appId) {
        throw const AuthFailure('wrong-project');
      }
      _auth = FirebaseAuth.instanceFor(app: app);
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
  Future<AuthIdentity> signIn() async {
    try {
      // Called directly from the button gesture; no await before opening popup.
      final result = await _auth!.signInWithPopup(GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'}));
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
