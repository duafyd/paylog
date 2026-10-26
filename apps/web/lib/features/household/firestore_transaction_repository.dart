import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_port.dart';
import '../google_connection/google_oauth.dart';
import '../transactions/transaction.dart';
import '../transactions/transaction_repository.dart';
import 'household.dart';

class FirestoreTransactionRepository extends TransactionRepository {
  FirestoreTransactionRepository(
      this.db, this.home, this.user, DateTime month) {
    setMonth(month);
  }
  final FirebaseFirestore db;
  final Household home;
  final AuthIdentity user;
  final _events = StreamController<int>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  List<BudgetTransaction> _items = [];
  List<LedgerMember> _people = [];
  DateTime _month = DateTime(2000);
  DocumentSnapshot<Map<String, dynamic>>? _last;
  int _generation = 0, _excluded = 0, _eventVersion = 0;
  bool _disposed = false;
  bool hasMore = false;
  bool loading = true;
  String? error;
  CollectionReference<Map<String, dynamic>> get _collection =>
      db.collection('households').doc(home.id).collection('transactions');
  Query<Map<String, dynamic>> get _query {
    final start = DateTime.utc(_month.year, _month.month)
        .subtract(const Duration(hours: 9));
    final end = DateTime.utc(_month.year, _month.month + 1)
        .subtract(const Duration(hours: 9));
    return _collection
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('occurredAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('occurredAt', descending: true)
        .limit(500);
  }

  void _emit() {
    if (!_disposed) _events.add(++_eventVersion);
  }

  @override
  Stream<int> get changes => _events.stream;
  @override
  String? get householdId => home.id;
  @override
  String? get sheetId => null;
  @override
  String get title => home.name;
  @override
  bool get canWrite => !_disposed && error == null;
  @override
  int get excludedCount => _excluded;
  @override
  LedgerMember get actor => LedgerMember(
      id: user.uid,
      name: user.username,
      role: home.ownerId == user.uid ? 'owner' : 'editor');
  @override
  List<LedgerMember> get ledgerMembers {
    final people = {
      actor.id: actor,
      for (final person in _people) person.id: person
    };
    // Transaction authors remain visible in breakdowns even when their roster
    // page has not been loaded or they joined after the roster was refreshed.
    for (final item in _items) {
      people.putIfAbsent(
          item.memberId,
          () => LedgerMember(
              id: item.memberId, name: item.member, role: 'editor'));
    }
    return people.values.toList();
  }

  void setMembers(List<HouseholdMember> people) {
    _people = people
        .map((p) => LedgerMember(
            id: p.uid,
            name: p.username,
            role: p.role == 'owner' ? 'owner' : 'editor'))
        .toList();
    _emit();
  }

  @override
  List<BudgetTransaction> readAll() => List.unmodifiable(_items);
  void setMonth(DateTime month) {
    if (_disposed) return;
    _month = DateTime(month.year, month.month);
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    loading = true;
    _items = [];
    _last = null;
    _excluded = 0;
    hasMore = false;
    error = null;
    _emit();
    _subscription =
        _query.snapshots(includeMetadataChanges: true).listen((snapshot) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        return;
      }
      if (!_disposed && generation == _generation) _apply(snapshot.docs);
    }, onError: (Object _) {
      if (_disposed || generation != _generation) return;
      _items = [];
      loading = false;
      error = '원장을 동기화하지 못했어요. 연결과 권한을 확인하고 새로고침해 주세요.';
      _emit();
    });
  }

  void _apply(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      {bool append = false}) {
    try {
      final visible = <BudgetTransaction>[];
      var excluded = 0;
      for (final doc in docs) {
        final d = doc.data();
        if (d['deletedAt'] != null) {
          excluded++;
          continue;
        }
        visible.add(BudgetTransaction(
            id: doc.id,
            type: TransactionType.values.byName(d['type'] as String),
            amount: d['amount'] as int,
            occurredAt: seoulTime((d['occurredAt'] as Timestamp).toDate()),
            merchant: d['merchant'] as String,
            memo: d['memo'] as String,
            categoryId: d['categoryId'] as String,
            member: d['memberName'] as String,
            memberId: d['memberId'] as String,
            paymentMethod: d['paymentMethod'] as String,
            revision: '${d['version']}'));
      }
      _items = append
          ? [
              ..._items,
              ...visible.where((t) => !_items.any((old) => old.id == t.id))
            ]
          : visible;
      _excluded = append ? _excluded + excluded : excluded;
      _last = docs.isEmpty ? _last : docs.last;
      hasMore = docs.length == 500;
      error = null;
    } catch (_) {
      _items = [];
      error = '지원하지 않는 원장 데이터가 있어요. 운영자에게 알려 주세요.';
    }
    loading = false;
    _emit();
  }

  @override
  Future<void> refresh() async {
    final generation = _generation;
    final snapshot = await _query.get(const GetOptions(source: Source.server));
    if (!_disposed && generation == _generation) _apply(snapshot.docs);
  }

  Future<void> more() async {
    if (!hasMore || _last == null || _disposed) return;
    final generation = _generation;
    final result = await _query
        .startAfterDocument(_last!)
        .get(const GetOptions(source: Source.server));
    if (!_disposed && generation == _generation) {
      _apply(result.docs, append: true);
    }
  }

  Map<String, dynamic> _fields(BudgetTransaction t) => {
        'type': t.type.name,
        'amount': t.amount,
        'occurredAt': Timestamp.fromDate(DateTime.utc(
                t.occurredAt.year,
                t.occurredAt.month,
                t.occurredAt.day,
                t.occurredAt.hour,
                t.occurredAt.minute)
            .subtract(const Duration(hours: 9))),
        'merchant': t.merchant,
        'memo': t.memo,
        'categoryId': t.categoryId,
        'memberId': t.memberId,
        'memberName': t.member,
        'paymentMethod': t.paymentMethod,
      };
  bool _matches(Map<String, dynamic> data, BudgetTransaction t) =>
      _fields(t).entries.every((e) => data[e.key] == e.value);
  Future<void> _write(BudgetTransaction value, String operation) async {
    if (_disposed) throw const ConnectionFailure('다시 로그인하고 원장을 연결해 주세요.');
    final reference = _collection.doc(value.id);
    try {
      await db.runTransaction((tx) async {
        final existing = await tx.get(reference);
        final old = existing.data();
        final expected = operation == 'add' ? 0 : int.tryParse(value.revision);
        if (expected == null) {
          throw const ConnectionFailure('원장을 다시 불러온 뒤 수정해 주세요.');
        }
        if (old != null &&
            old['updatedBy'] == user.uid &&
            old['version'] == expected + 1 &&
            (operation == 'delete'
                ? old['deletedAt'] != null
                : old['deletedAt'] == null && _matches(old, value))) {
          return;
        }
        if (operation == 'add') {
          if (old != null) {
            throw const ConnectionFailure('같은 ID의 다른 기록이 있어요. 원장을 확인해 주세요.');
          }
          tx.set(reference, {
            ..._fields(value),
            'version': 1,
            'createdBy': user.uid,
            'updatedBy': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'deletedAt': null
          });
        } else {
          if (old == null ||
              old['version'] != expected ||
              old['deletedAt'] != null) {
            throw const ConnectionFailure(
                '다른 곳에서 변경된 기록이에요. 새로고침 후 다시 수정해 주세요.');
          }
          tx.update(reference, {
            ...(operation == 'delete' ? <String, dynamic>{} : _fields(value)),
            'version': expected + 1,
            'updatedBy': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
            if (operation == 'delete') 'deletedAt': FieldValue.serverTimestamp()
          });
        }
      });
      await refresh();
    } on ConnectionFailure {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const ConnectionFailure('이 원장에 기록할 권한이 없거나 입력 조건이 맞지 않아요.');
      }
      throw const ConnectionFailure('저장 결과를 확인하지 못했어요. 같은 기록으로 결과를 다시 확인해 주세요.',
          uncertainWrite: true);
    }
  }

  @override
  Future<void> add(BudgetTransaction transaction) => _write(transaction, 'add');
  @override
  Future<void> update(BudgetTransaction transaction) =>
      _write(transaction, 'update');
  @override
  Future<void> delete(BudgetTransaction transaction) =>
      _write(transaction, 'delete');
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _items = [];
    unawaited(_subscription?.cancel());
    unawaited(_events.close());
  }
}
