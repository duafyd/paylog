import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../transactions/transaction_repository.dart';
import '../../core/theme/app_theme.dart';

class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(visibleMonthProvider);
    void move(int delta) {
      final next = DateTime(month.year, month.month + delta);
      ref.read(visibleMonthProvider.notifier).state = next;
      ref.read(selectedDayProvider.notifier).state = next;
    }

    return Row(children: [
      Expanded(
          child: Text('${month.year}년 ${month.month}월',
              style: Theme.of(context).textTheme.headlineSmall)),
      IconButton(
          tooltip: '이전 달',
          onPressed: () => move(-1),
          icon: const Icon(Icons.chevron_left)),
      IconButton(
          tooltip: '다음 달',
          onPressed: () => move(1),
          icon: const Icon(Icons.chevron_right)),
      TextButton(
          onPressed: () {
            final now = ref.read(clockProvider)();
            ref.read(visibleMonthProvider.notifier).state =
                DateTime(now.year, now.month);
            ref.read(selectedDayProvider.notifier).state = now;
          },
          child: const Text('오늘', style: TextStyle(color: AppColors.accent))),
    ]);
  }
}
