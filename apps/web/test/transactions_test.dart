import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/features/transactions/transaction.dart';
import 'package:paylog/features/transactions/transaction_repository.dart';

void main() {
  test('월별 합계는 다른 달을 제외하고 신규 수입과 지출을 반영한다', () {
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 20))
    ]);
    addTearDown(container.dispose);
    final initial = container.read(monthlyTransactionsProvider);
    expect(initial, hasLength(6));
    expect(totalOf(initial, TransactionType.expense), 180600);
    expect(totalOf(initial, TransactionType.income), 4200000);
    for (final (id, month, amount, type) in [
      ('new-expense', 10, 1500, TransactionType.expense),
      ('new-income', 10, 20000, TransactionType.income),
      ('other-month', 11, 99999, TransactionType.expense),
    ]) {
      container.read(transactionsProvider.notifier).add(BudgetTransaction(
          id: id,
          type: type,
          amount: amount,
          occurredAt: DateTime(2026, month, 20),
          merchant: '테스트',
          categoryId: type == TransactionType.expense ? 'food' : 'salary',
          member: '눈이'));
    }
    final updated = container.read(monthlyTransactionsProvider);
    expect(updated, hasLength(8));
    expect(totalOf(updated, TransactionType.expense), 182100);
    expect(totalOf(updated, TransactionType.income), 4220000);
    container.read(visibleMonthProvider.notifier).state = DateTime(2026, 11);
    expect(
        container.read(monthlyTransactionsProvider).single.id, 'other-month');
  });
  test('저장소는 0원, 음수 및 중복 ID를 거부한다', () {
    final repository = InMemoryTransactionRepository(DateTime(2026, 10, 20));
    BudgetTransaction item(String id, int amount) => BudgetTransaction(
        id: id,
        type: TransactionType.expense,
        amount: amount,
        occurredAt: DateTime(2026),
        merchant: '테스트',
        categoryId: 'food',
        member: '눈이');
    expect(() => repository.add(item('zero', 0)), throwsArgumentError);
    expect(() => repository.add(item('negative', -1)), throwsArgumentError);
    expect(() => repository.add(item('too-large', 1000000000000)),
        throwsArgumentError);
    repository.add(item('unique', 100));
    expect(() => repository.add(item('unique', 100)), throwsStateError);
  });
  test('금액과 날짜 비교는 연도와 월 경계를 구분한다', () {
    expect(won(1234567), '₩1,234,567');
    expect(sameDay(DateTime(2026, 10, 1, 23), DateTime(2026, 10, 1)), isTrue);
    expect(sameMonth(DateTime(2025, 10), DateTime(2026, 10)), isFalse);
  });
}
