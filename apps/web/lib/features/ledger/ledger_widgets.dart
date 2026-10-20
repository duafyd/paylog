import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';
import '../google_connection/google_connection.dart';
import '../transactions/transaction_repository.dart';
import 'ledger_session.dart';

class LedgerStatus extends ConsumerWidget {
  const LedgerStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(transactionRepositoryProvider);
    final status = ref.watch(ledgerSessionProvider);
    if (repository.sheetId == null && status.error == null) {
      return const SizedBox.shrink();
    }
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: BentoCard(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (repository.sheetId != null) ...[
                SectionHeader('Sheets · ${repository.title}',
                    trailing: IconButton(
                        tooltip: '원장 새로고침',
                        onPressed: status.busy
                            ? null
                            : () => ref
                                .read(ledgerSessionProvider.notifier)
                                .refresh(),
                        icon: const Icon(Icons.refresh))),
                Text(
                    repository.canWrite
                        ? '공유 원장 · 서울 시간 기준'
                        : '조회 전용 · 서울 시간 기준',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                if (repository.excludedCount > 0)
                  Text('취소·검토 대기·삭제 ${repository.excludedCount}건은 요약에서 제외했어요.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
              ],
              if (status.busy)
                const LinearProgressIndicator(semanticsLabel: '원장 불러오는 중'),
              if (status.error != null)
                Semantics(
                    liveRegion: true,
                    child: Text(status.error!,
                        style: const TextStyle(color: AppColors.expense))),
            ])));
  }
}

class LedgerConnectionPanel extends ConsumerStatefulWidget {
  const LedgerConnectionPanel({super.key});
  @override
  ConsumerState<LedgerConnectionPanel> createState() =>
      _LedgerConnectionPanelState();
}

class _LedgerConnectionPanelState extends ConsumerState<LedgerConnectionPanel> {
  final _id = TextEditingController();
  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('새 가계부를 만들까요?'),
                content: const Text(
                    '본인 Google Drive에 Transactions·Members 탭이 있는 새 가계부를 만들고 현재 계정을 구성원으로 기록합니다. 기존 시트는 바꾸지 않습니다. 샘플 거래는 복사하지 않습니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('가계부 생성·연결'))
                ]));
    if (confirmed == true && mounted) {
      await ref.read(ledgerSessionProvider.notifier).create();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(ledgerSessionProvider),
        google = ref.watch(googleConnectionProvider);
    final repository = ref.watch(transactionRepositoryProvider);
    final enabled = !status.busy && !google.busy && google.profile != null;
    return BentoCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('달력에 실제 원장 연결'),
      const SizedBox(height: 12),
      const Text(
          '위의 로그인·Sheets 동의를 완료한 뒤 연결하세요. Members UUID를 검증한 원장만 표시하며 샘플 거래와 합치지 않습니다.'),
      const SizedBox(height: 12),
      Semantics(
          container: true,
          explicitChildNodes: true,
          child: TextField(
              controller: _id,
              enabled: !status.busy,
              decoration:
                  const InputDecoration(labelText: '연결할 가계부 ID 또는 URL'))),
      const SizedBox(height: 12),
      OutlinedButton(
          onPressed: enabled
              ? () => ref.read(ledgerSessionProvider.notifier).connect(_id.text)
              : null,
          child: const Text('기존 가계부 연결')),
      FilledButton(
          onPressed: enabled ? _create : null,
          child: const Text('새 가계부 템플릿 만들기')),
      if (repository.sheetId != null) ...[
        const SizedBox(height: 8),
        Text('연결됨 · ${repository.title}'),
        SelectableText(
            'https://docs.google.com/spreadsheets/d/${repository.sheetId}/edit'),
        TextButton(
            onPressed: status.busy
                ? null
                : () => ref.read(ledgerSessionProvider.notifier).useSample(),
            child: const Text('샘플 모드로 돌아가기')),
      ],
      if (status.busy)
        const LinearProgressIndicator(semanticsLabel: '가계부 연결 중'),
      if (status.error != null)
        Semantics(
            liveRegion: true,
            child: Text(status.error!,
                style: const TextStyle(color: AppColors.expense))),
      if (status.createdId != null &&
          repository.sheetId != status.createdId) ...[
        const Text('생성된 시트를 먼저 확인하세요. 초기화 실패 시 자동으로 다시 생성하지 않습니다.'),
        SelectableText(
            'https://docs.google.com/spreadsheets/d/${status.createdId}/edit'),
      ],
    ]));
  }
}
