import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';
import '../transactions/transaction.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard(
      {super.key,
      required this.title,
      required this.amount,
      this.primary = false,
      this.label});
  final String title;
  final int amount;
  final bool primary;
  final String? label;
  @override
  Widget build(BuildContext context) => BentoCard(
        color: primary
            ? AppColors.dark
            : (title == '남은 금액' ? AppColors.tealSoft : AppColors.surface),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: primary ? Colors.white : AppColors.muted,
                        fontSize: 13))),
            Icon(
                primary
                    ? Icons.north_east_rounded
                    : title == '총 수입'
                        ? Icons.south_west_rounded
                        : Icons.account_balance_wallet_outlined,
                size: 20,
                color: primary ? AppColors.lime : AppColors.teal),
          ]),
          const SizedBox(height: 22),
          Text(won(amount),
              style: AppTheme.numberStyle.copyWith(
                  fontSize: primary ? 36 : 20,
                  fontWeight: FontWeight.w700,
                  color: primary ? AppColors.lime : AppColors.ink,
                  letterSpacing: -.7)),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!,
                style: const TextStyle(color: Color(0xFFCCD8CF), fontSize: 12)),
          ],
        ]),
      );
}

class SummaryGrid extends StatelessWidget {
  const SummaryGrid(
      {super.key,
      required this.expense,
      required this.income,
      required this.count});
  final int expense;
  final int income;
  final int count;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final primary = SummaryCard(
            title: '이번 달 지출',
            amount: expense,
            primary: true,
            label: '우리 가족 $count건의 작은 기록');
        final secondary = [
          SummaryCard(title: '총 수입', amount: income),
          SummaryCard(title: '남은 금액', amount: income - expense)
        ];
        if (constraints.maxWidth >= 760 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
          return IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Expanded(flex: 2, child: primary),
                for (final card in secondary) ...[
                  const SizedBox(width: 12),
                  Expanded(child: card)
                ],
              ]));
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              const SizedBox(height: 12),
              Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: secondary
                      .map((card) => SizedBox(
                          width: constraints.maxWidth < 300 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.3
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2,
                          child: card))
                      .toList()),
            ]);
      });
}
