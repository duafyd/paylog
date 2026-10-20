import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../transactions/transaction_repository.dart';
import '../ledger/ledger_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text('우리 집 가계부', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('가볍게 시작하는 함께의 기록', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 24),
        const LedgerStatus(),
        if (ref.watch(transactionRepositoryProvider).sheetId == null)
          const BentoCard(
              color: AppColors.tealSoft,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.science_outlined, color: AppColors.teal),
                    SizedBox(height: 12),
                    SectionHeader('지금은 샘플 모드예요'),
                    SizedBox(height: 8),
                    Text(
                        '눈이와 딘이의 가상 거래로 화면을 둘러볼 수 있어요. 추가한 기록은 현재 세션에만 보관되고 새로고침하면 초기화됩니다.'),
                  ])),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: () => context.go('/google-connection'),
            icon: const Icon(Icons.link),
            label: const Text('Google 연결 검증 열기')),
        const SizedBox(height: 16),
        const BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader('연결과 다음 기능'),
          SizedBox(height: 16),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_circle_outlined),
              title: Text('Google 로그인'),
              subtitle: Text('연결 검증 화면에서 로그인을 시험할 수 있어요.')),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.table_chart_outlined),
              title: Text('Google Sheets 연결'),
              subtitle: Text('원장을 연결하면 달력·등록·통계에 반영됩니다.')),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.sms_outlined),
              title: Text('SMS 자동 수집'),
              subtitle: Text('별도 보조 앱·단축어와 실기기 검증이 필요해요.')),
        ])),
        const SizedBox(height: 16),
        const BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader('홈 화면에서 더 편하게'),
          SizedBox(height: 12),
          Text(
              'Android Chrome: 메뉴 → 홈 화면에 추가\n\niPhone Safari: 공유 → 홈 화면에 추가\n\nHTTPS 배포 후 사용할 수 있어요. 현재 단계는 온라인 실행 기준이며 오프라인 저장·동기화는 지원하지 않습니다.'),
        ])),
        const SizedBox(height: 24),
        const Text('paylog 0.1.0 · Phase 1',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ]);
}
