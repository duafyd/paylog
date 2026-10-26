import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/bento_card.dart';
import '../google_connection/google_oauth.dart';
import '../google_connection/google_connection.dart';
import 'transaction.dart';
import 'transaction_repository.dart';

class TransactionDetail extends ConsumerStatefulWidget {
  const TransactionDetail({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TransactionDetail> createState() => _TransactionDetailState();
}

class _TransactionDetailState extends ConsumerState<TransactionDetail> {
  BudgetTransaction? _pending;
  bool _busy = false, _uncertain = false;
  String? _error;
  Future<void> _delete(BudgetTransaction transaction) async {
    if (!_uncertain) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('이 기록을 삭제할까요?'),
                content:
                    const Text('합계에서 제외됩니다. 연결된 원장에는 삭제 상태와 감사 정보가 남을 수 있습니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제'))
                ],
              ));
      if (yes != true || !mounted) return;
    }
    _pending ??= transaction;
    final repository = ref.read(transactionRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(transactionsProvider.notifier).delete(_pending!);
      if (mounted &&
          identical(repository, ref.read(transactionRepositoryProvider))) {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ConnectionFailure ? e.message : '삭제하지 못했어요. 다시 확인해 주세요.';
        _uncertain = e is ConnectionFailure && e.uncertainWrite;
        _busy = false;
      });
      if (e is ConnectionFailure && e.reauthenticate) {
        ref.read(googleConnectionProvider).invalidateSession();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(transactionRepositoryProvider);
    final found =
        ref.watch(transactionsProvider).where((t) => t.id == widget.id);
    final t = _pending ?? (found.isEmpty ? null : found.first);
    if (t == null) {
      return Center(
          child: TextButton(
              onPressed: () => context.go('/'),
              child: const Text('거래를 찾을 수 없어요. 달력으로 돌아가기')));
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('기록 상세', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      BentoCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.merchant, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(won(t.amount), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Text(
            '${t.type == TransactionType.income ? '수입' : '지출'} · ${t.category.label}'),
        Text('${t.member} · ${t.paymentMethod}'),
        Text('${t.occurredAt} (서울)'),
        if (t.memo.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(t.memo)),
      ])),
      const SizedBox(height: 20),
      if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
      FilledButton.icon(
          onPressed: repository.canWrite && !_busy && !_uncertain
              ? () => context.go('/edit/${t.id}')
              : null,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('기록 수정')),
      OutlinedButton.icon(
          onPressed: !_busy && (repository.canWrite || _uncertain)
              ? () => _delete(t)
              : null,
          icon: const Icon(Icons.delete_outline),
          label: Text(_busy
              ? '확인 중…'
              : _uncertain
                  ? '삭제 결과 다시 확인'
                  : '기록 삭제')),
      TextButton(
          onPressed: () => context.go('/'), child: const Text('달력으로 돌아가기')),
    ]);
  }
}
