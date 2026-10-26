class AuthIdentity {
  const AuthIdentity({required this.uid, required this.username});
  final String uid;
  final String username;
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);
  final String code;
}

/// Tokens and passwords never become profile data in the UI/controller model.
abstract interface class AuthPort {
  Future<AuthIdentity?> initialize();
  Stream<AuthIdentity?> get changes;
  Future<AuthIdentity> signIn(String username, String password);
  Future<AuthIdentity> register(String username, String password);
  Future<void> signOut();
}
