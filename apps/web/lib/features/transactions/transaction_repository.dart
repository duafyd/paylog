import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction.dart';

abstract interface class TransactionRepository {
  List<BudgetTransaction> readAll();
  Future<void> add(BudgetTransaction transaction);
  Future<void> refresh();
  List<LedgerMember> get ledgerMembers;
  LedgerMember? get actor;
  bool get canWrite;
  String? get sheetId;
  String get title;
  int get excludedCount;
}

/// Session-only demo store. Replace this provider with a Sheets adapter in Phase 2.
class InMemoryTransactionRepository implements TransactionRepository {
  InMemoryTransactionRepository(DateTime now)
      : _items = [
          BudgetTransaction(
              id: 'sample-1',
              type: TransactionType.income,
              amount: 4200000,
              occurredAt: DateTime(now.year, now.month, 1),
              merchant: '이번 달 급여',
              categoryId: 'salary',
              member: '눈이',
              paymentMethod: '계좌이체'),
          BudgetTransaction(
              id: 'sample-2',
              type: TransactionType.expense,
              amount: 13200,
              occurredAt: DateTime(now.year, now.month, now.day, 12),
              merchant: '오늘의 점심',
              categoryId: 'food',
              member: '눈이'),
          BudgetTransaction(
              id: 'sample-3',
              type: TransactionType.expense,
              amount: 54800,
              occurredAt: DateTime(now.year, now.month, now.day, 15),
              merchant: '우리동네 마트',
              categoryId: 'groceries',
              member: '딘이'),
          BudgetTransaction(
              id: 'sample-4',
              type: TransactionType.expense,
              amount: 9600,
              occurredAt: DateTime(now.year, now.month, 3),
              merchant: '모퉁이 커피',
              categoryId: 'cafe',
              member: '딘이'),
          BudgetTransaction(
              id: 'sample-5',
              type: TransactionType.expense,
              amount: 68000,
              occurredAt: DateTime(now.year, now.month, 8),
              merchant: '주말의 식탁',
              categoryId: 'food',
              member: '눈이'),
          BudgetTransaction(
              id: 'sample-6',
              type: TransactionType.expense,
              amount: 35000,
              occurredAt: DateTime(now.year, now.month, 12),
              merchant: '교통카드 충전',
              categoryId: 'transport',
              member: '딘이'),
        ];
  final List<BudgetTransaction> _items;
  @override
  Future<void> refresh() async {}
  @override
  List<LedgerMember> get ledgerMembers =>
      members.map((m) => LedgerMember(id: m, name: m)).toList();
  @override
  LedgerMember? get actor => null;
  @override
  bool get canWrite => true;
  @override
  String? get sheetId => null;
  @override
  String get title => '샘플 가계부';
  @override
  int get excludedCount => 0;
  @override
  List<BudgetTransaction> readAll() => List.unmodifiable(_items);
  @override
  Future<void> add(BudgetTransaction transaction) async {
    if (transaction.amount <= 0 || transaction.amount > 999999999999) {
      throw ArgumentError('금액 범위를 확인해 주세요.');
    }
    if (_items.any((item) => item.id == transaction.id)) {
      throw StateError('이미 저장된 거래입니다.');
    }
    _items.add(transaction);
  }
}

final clockProvider =
    Provider<DateTime Function()>((ref) => () => seoulTime(DateTime.now()));
final demoRepositoryProvider = Provider<TransactionRepository>(
    (ref) => InMemoryTransactionRepository(ref.read(clockProvider)()));
final activeRepositoryProvider =
    StateProvider<TransactionRepository?>((ref) => null);
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) =>
    ref.watch(activeRepositoryProvider) ?? ref.watch(demoRepositoryProvider));
final ledgerMembersProvider = Provider<List<LedgerMember>>((ref) {
  ref.watch(transactionsProvider);
  return ref.watch(transactionRepositoryProvider).ledgerMembers;
});
final transactionsProvider =
    NotifierProvider<TransactionsController, List<BudgetTransaction>>(
        TransactionsController.new);

class TransactionsController extends Notifier<List<BudgetTransaction>> {
  int _generation = 0;
  bool _saving = false;
  @override
  List<BudgetTransaction> build() {
    _generation++;
    ref.onDispose(() => _generation++);
    return ref.watch(transactionRepositoryProvider).readAll();
  }

  Future<void> add(BudgetTransaction transaction) async {
    if (_saving) throw StateError('저장 중입니다.');
    _saving = true;
    final generation = _generation;
    final repository = ref.read(transactionRepositoryProvider);
    try {
      await repository.add(transaction);
      if (_generation == generation) state = repository.readAll();
    } finally {
      _saving = false;
    }
  }

  Future<void> refresh() async {
    final generation = _generation;
    final repository = ref.read(transactionRepositoryProvider);
    await repository.refresh();
    if (_generation == generation) state = repository.readAll();
  }
}

final selectedDayProvider =
    StateProvider<DateTime>((ref) => ref.read(clockProvider)());
final visibleMonthProvider = StateProvider<DateTime>((ref) {
  final now = ref.read(clockProvider)();
  return DateTime(now.year, now.month);
});
final monthlyTransactionsProvider = Provider<List<BudgetTransaction>>((ref) {
  final month = ref.watch(visibleMonthProvider);
  return ref
      .watch(transactionsProvider)
      .where((t) => sameMonth(t.occurredAt, month))
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
});
