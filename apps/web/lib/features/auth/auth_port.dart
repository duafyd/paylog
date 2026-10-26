class AuthIdentity {
  const AuthIdentity(
      {required this.uid, required this.email, required this.name});
  final String uid;
  final String? email;
  final String? name;
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);
  final String code;
}

/// Tokens stay inside the Firebase SDK; UI/controller receive profile data only.
abstract interface class AuthPort {
  Future<AuthIdentity?> initialize();
  Stream<AuthIdentity?> get changes;
  Future<AuthIdentity> signIn();
  Future<void> signOut();
}
