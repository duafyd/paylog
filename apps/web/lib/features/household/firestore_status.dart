import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/bento_card.dart';
import '../transactions/transaction_repository.dart';
import 'firestore_transaction_repository.dart';

class FirestoreStatus extends ConsumerWidget {
  const FirestoreStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(transactionsProvider);
    final repository = ref.watch(transactionRepositoryProvider);
    if (repository is! FirestoreTransactionRepository) {
      return const SizedBox.shrink();
    }
    Future<void> run(Future<void> Function() action) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          messenger.showSnackBar(
              const SnackBar(content: Text('원장을 불러오지 못했어요. 연결과 권한을 확인해 주세요.')));
        }
      }
    }

    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(repository.title),
          const Text('공동 원장 · 변경사항 자동 동기화'),
          if (repository.hasMore)
            const Text(
                '아직 불러오지 않은 기록이 있어요. 합계·통계·CSV는 현재 불러온 기록 기준이에요. 이 달 기록 더 보기를 눌러 주세요.'),
          if (repository.loading) const LinearProgressIndicator(),
          if (repository.error != null)
            Semantics(liveRegion: true, child: Text(repository.error!)),
          Wrap(spacing: 8, children: [
            TextButton.icon(
                onPressed: () => run(repository.refresh),
                icon: const Icon(Icons.refresh),
                label: const Text('원장 새로고침')),
            TextButton(
                onPressed: () => context.go('/household'),
                child: const Text('초대 · 멤버 관리')),
            TextButton(
                onPressed: () => context.go('/sms-devices'),
                child: const Text('문자 수집함 · 기기 연결')),
            if (repository.hasMore)
              TextButton(
                  onPressed: () => run(repository.more),
                  child: const Text('이 달 기록 더 보기')),
          ]),
        ])));
  }
}
