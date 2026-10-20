import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction.dart';

abstract interface class TransactionRepository {
  List<BudgetTransaction> readAll();
  void add(BudgetTransaction transaction);
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
  List<BudgetTransaction> readAll() => List.unmodifiable(_items);
  @override
  void add(BudgetTransaction transaction) {
    if (transaction.amount <= 0 || transaction.amount > 999999999999) {
      throw ArgumentError('금액 범위를 확인해 주세요.');
    }
    if (_items.any((item) => item.id == transaction.id)) {
      throw StateError('이미 저장된 거래입니다.');
    }
    _items.add(transaction);
  }
}

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final transactionRepositoryProvider = Provider<TransactionRepository>(
    (ref) => InMemoryTransactionRepository(ref.read(clockProvider)()));
final transactionsProvider =
    NotifierProvider<TransactionsController, List<BudgetTransaction>>(
        TransactionsController.new);

class TransactionsController extends Notifier<List<BudgetTransaction>> {
  @override
  List<BudgetTransaction> build() =>
      ref.watch(transactionRepositoryProvider).readAll();
  void add(BudgetTransaction transaction) {
    final repository = ref.read(transactionRepositoryProvider);
    repository.add(transaction);
    state = repository.readAll();
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
