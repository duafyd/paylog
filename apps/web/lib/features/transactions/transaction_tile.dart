import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile(this.transaction, {super.key});
  final BudgetTransaction transaction;
  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final income = t.type == TransactionType.income;
    return InkWell(
        onTap: () => context.go('/transaction/${t.id}'),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(t.category.icon,
                        color: AppColors.accent, size: 22)),
                const SizedBox(width: Space.md),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(t.merchant,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          '${t.category.label} · ${t.member} · ${t.paymentMethod}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                      if (t.memo.isNotEmpty)
                        Text(t.memo,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                    ])),
                const SizedBox(width: Space.sm),
                Flexible(
                    child: Text('${income ? '+' : '-'}${won(t.amount)}',
                        textAlign: TextAlign.end,
                        semanticsLabel: '${income ? '수입' : '지출'} ${t.amount}원',
                        style: AppTheme.numberStyle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: income
                                ? AppColors.accent
                                : AppColors.expense))),
              ],
            )));
  }
}
