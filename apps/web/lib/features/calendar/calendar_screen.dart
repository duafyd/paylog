import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';
import '../transactions/transaction.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_tile.dart';
import 'calendar_card.dart';
import 'month_selector.dart';
import 'summary_card.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(monthlyTransactionsProvider);
    final selected = ref.watch(selectedDayProvider);
    final daily = items.where((t) => sameDay(t.occurredAt, selected)).toList();
    final expense = totalOf(items, TransactionType.expense);
    final income = totalOf(items, TransactionType.income);
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Text('함께 쓰고, 가볍게 모으는',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 4),
          const MonthSelector(),
          const SizedBox(height: 20),
          SummaryGrid(
              expense: expense,
              income: income,
              count:
                  items.where((t) => t.type == TransactionType.expense).length),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final calendar =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeader('한 달의 흐름'),
              const SizedBox(height: 12),
              const CalendarCard(),
              const SizedBox(height: 8),
              const Text('달력 금액은 요약 표시 · 날짜를 누르면 정확한 금액을 볼 수 있어요.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ]);
            final details =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader('${selected.month}월 ${selected.day}일의 기록',
                  trailing: IconButton(
                      tooltip: '선택 날짜에 거래 등록',
                      onPressed: () => context.go('/add'),
                      icon: const Icon(Icons.add_circle_outline))),
              const SizedBox(height: 8),
              BentoCard(
                  child: daily.isEmpty
                      ? const EmptyState(
                          message: '아직 기록이 없는 날이에요.\n새로운 거래를 남겨 보세요.')
                      : Column(
                          children: daily.map(TransactionTile.new).toList())),
              const SizedBox(height: 20),
              const SectionHeader('함께 기록한 지출'),
              const SizedBox(height: 12),
              ...members.map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BentoCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.tealSoft,
                            child: Text(member.substring(0, 1),
                                style: const TextStyle(color: AppColors.teal))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(member)),
                        Flexible(
                            child: Text(
                                won(totalOf(
                                    items.where((t) => t.member == member),
                                    TransactionType.expense)),
                                style: AppTheme.numberStyle
                                    .copyWith(fontWeight: FontWeight.w700))),
                      ])))),
            ]);
            if (constraints.maxWidth >= 760) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: calendar),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: details),
                  ]);
            }
            return Column(
                children: [calendar, const SizedBox(height: 20), details]);
          }),
        ]);
  }
}
