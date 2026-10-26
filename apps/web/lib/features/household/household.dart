import '../auth/auth_port.dart';

class Household {
  const Household(
      {required this.id, required this.name, required this.ownerId});
  final String id, name, ownerId;
}

class HouseholdMember {
  const HouseholdMember(
      {required this.uid, required this.username, required this.role});
  final String uid, username, role;
}

class HouseholdInvite {
  const HouseholdInvite(this.code, this.expiresAt);
  final String code;
  final DateTime expiresAt;
}

class MemberPage {
  const MemberPage(this.members, this.hasMore);
  final List<HouseholdMember> members;
  final bool hasMore;
}

class HouseholdFailure implements Exception {
  const HouseholdFailure(this.message);
  final String message;
}

abstract interface class HouseholdPort {
  Future<Household?> load(AuthIdentity user);
  Future<Household> create(AuthIdentity user, String name);
  Future<Household> join(AuthIdentity user, String code);
  Future<HouseholdInvite> invite(AuthIdentity user, Household household);
  Future<void> revokeInvite(AuthIdentity user, String code);
  Future<MemberPage> members(Household household, {String? afterUid});
}
