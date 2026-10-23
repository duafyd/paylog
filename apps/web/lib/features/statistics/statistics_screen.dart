import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';
import '../calendar/month_selector.dart';
import '../calendar/summary_card.dart';
import '../ledger/ledger_widgets.dart';
import '../transactions/transaction.dart';
import '../transactions/transaction_repository.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(ledgerMembersProvider);
    final items = ref.watch(monthlyTransactionsProvider);
    final expense = totalOf(items, TransactionType.expense);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('숫자로 보는 우리 집', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      const Text('기록을 모아, 소비의 흐름을 살펴봐요.',
          style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 20),
      const MonthSelector(),
      const LedgerStatus(),
      const SizedBox(height: 20),
      SummaryCard(
          title: '이번 달 지출',
          amount: expense,
          primary: true,
          label: '이번 달 기록을 기준으로 집계했어요'),
      const SizedBox(height: 16),
      BentoCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('어디에 사용했을까요?'),
        const SizedBox(height: 20),
        if (expense == 0) const EmptyState(message: '이번 달에는 아직 지출이 없어요.'),
        ...ref
            .watch(transactionRepositoryProvider)
            .categoryCatalog
            .where((c) => c.type == TransactionType.expense)
            .map((category) {
          final amount = totalOf(
              items.where((t) => t.categoryId == category.id),
              TransactionType.expense);
          if (amount == 0) return const SizedBox.shrink();
          final ratio = amount / expense;
          return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(children: [
                Row(children: [
                  Icon(category.icon, color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(category.label)),
                  Flexible(
                      child: Text(
                          '${won(amount)} · ${(ratio * 100).toStringAsFixed(1)}%',
                          textAlign: TextAlign.end,
                          style: AppTheme.numberStyle.copyWith(fontSize: 12)))
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: AppColors.accentSoft,
                        semanticsLabel: '${category.label} 지출 비율',
                        semanticsValue: '${(ratio * 100).round()}%')),
              ]));
        }),
      ])),
      const SizedBox(height: 16),
      BentoCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('가족별 지출'),
        const SizedBox(height: 16),
        ...people.map((member) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(child: Text(memberLabel(member, people))),
              Flexible(
                  child: Text(
                      won(totalOf(
                          items.where(
                              (t) => transactionMemberKey(t) == member.id),
                          TransactionType.expense)),
                      style: AppTheme.numberStyle
                          .copyWith(fontWeight: FontWeight.w700)))
            ]))),
      ])),
    ]);
  }
}
