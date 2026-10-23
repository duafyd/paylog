import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';
import '../transactions/transaction.dart';
import '../transactions/transaction_repository.dart';

class CalendarCard extends ConsumerWidget {
  const CalendarCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(visibleMonthProvider);
    final selected = ref.watch(selectedDayProvider);
    final today = ref.read(clockProvider)();
    final items = ref.watch(monthlyTransactionsProvider);
    final offset = month.weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + days) / 7).ceil();
    return BentoCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(
              children: ['일', '월', '화', '수', '목', '금', '토']
                  .map((day) => Expanded(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(day,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted))),
                      ))
                  .toList()),
          for (var row = 0; row < rows; row++)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: Builder(builder: (context) {
                  final day = row * 7 + col - offset + 1;
                  if (day < 1 || day > days) return const SizedBox(height: 68);
                  final date = DateTime(month.year, month.month, day);
                  final daily = items.where((t) => sameDay(t.occurredAt, date));
                  final expense = totalOf(daily, TransactionType.expense);
                  final income = totalOf(daily, TransactionType.income);
                  return DayCell(
                      date: date,
                      selected: sameDay(date, selected),
                      today: sameDay(date, today),
                      expense: expense,
                      income: income,
                      onTap: () =>
                          ref.read(selectedDayProvider.notifier).state = date);
                })),
            ]),
        ]));
  }
}

class DayCell extends StatelessWidget {
  const DayCell(
      {super.key,
      required this.date,
      required this.selected,
      required this.today,
      required this.expense,
      required this.income,
      required this.onTap});
  final DateTime date;
  final bool selected;
  final bool today;
  final int expense;
  final int income;
  final VoidCallback onTap;
  String compact(int amount) => amount >= 10000
      ? '${(amount / 10000).toStringAsFixed(amount % 10000 == 0 ? 0 : 1)}만'
      : '$amount';
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label:
            '${date.year}년 ${date.month}월 ${date.day}일${today ? ', 오늘' : ''}, 지출 $expense원, 수입 $income원',
        child: ExcludeSemantics(
            child: InkWell(
          key: ValueKey('day-${date.year}-${date.month}-${date.day}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 1),
            decoration: BoxDecoration(
                color: selected ? AppColors.dark : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: today ? AppColors.accent : Colors.transparent)),
            child: Column(children: [
              Text('${date.day}',
                  style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500)),
              if (expense > 0)
                Text('-${compact(expense)}',
                    style: TextStyle(
                        fontSize: 9,
                        color: selected
                            ? const Color(0xFFFFC9BA)
                            : AppColors.expense)),
              if (income > 0)
                Text('+${compact(income)}',
                    style: TextStyle(
                        fontSize: 9,
                        color:
                            selected ? AppColors.highlight : AppColors.accent)),
            ]),
          ),
        )),
      );
}
