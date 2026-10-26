import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../transactions/transaction_repository.dart';
import '../export/ledger_export.dart';
import '../export/download.dart';
import '../auth/auth_session.dart';
import '../ledger/ledger_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/platform/open_public_page.dart';
import '../../core/widgets/bento_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('우리 집 가계부', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('함께 쓰는 공간을, 우리답게.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          const LedgerStatus(),
          if (ref.watch(transactionRepositoryProvider).isDemo) ...[
            const BentoCard(
              color: AppColors.accentSoft,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.spa_outlined, color: AppColors.accent, size: 28),
                    SizedBox(height: 16),
                    SectionHeader('지금은 샘플 모드예요'),
                    SizedBox(height: 8),
                    Text(
                        '가상 거래로 먼저 둘러보세요. 실제 기록을 보관하려면 Google 계정과 우리 집 원장을 연결해 주세요.'),
                    SizedBox(height: 8),
                    Text('샘플 기록은 새로고침하면 초기화됩니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
            ),
            const SizedBox(height: 16),
          ],
          BentoCard(
              child: Column(children: [
            _SettingsAction(
                icon: Icons.account_circle_outlined,
                title: '로그인 및 계정',
                subtitle: ref.watch(firebaseSessionProvider).user?.username ??
                    '아이디로 로그인 · 간편 회원가입',
                onTap: () => context.go('/sign-in')),
            const Divider(height: 24),
            _SettingsAction(
                icon: Icons.link_rounded,
                title: 'Google 연결 검증 열기',
                subtitle: '이전 방식 · 기존 Sheets 원장 연결',
                onTap: () => context.go('/google-connection')),
            const Divider(height: 24),
            _SettingsAction(
                icon: Icons.people_outline_rounded,
                title: '공동 가계부 관리',
                subtitle: '가계부 만들기 · 초대 코드 · 멤버',
                onTap: () => context.go('/household')),
          ])),
          const SizedBox(height: 16),
          BentoCard(
              color: AppColors.secondarySurface,
              child: _SettingsAction(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Android · iPhone 사용 가이드',
                  subtitle: '홈 화면 설치부터 문자 수집까지',
                  onTap: () => context.go('/help'))),
          const SizedBox(height: 24),
          const SectionHeader('데이터와 서비스'),
          const SizedBox(height: 12),
          BentoCard(
              child: Column(children: [
            _SettingsAction(
                icon: Icons.file_download_outlined,
                title: '현재 원장 CSV 내보내기',
                subtitle: '지금 보고 있는 거래를 파일로 보관',
                onTap: () =>
                    downloadCsv(ledgerCsv(ref.read(transactionsProvider)))),
            const Divider(height: 24),
            _SettingsAction(
                icon: Icons.privacy_tip_outlined,
                title: '개인정보처리방침',
                onTap: () => openPublicPage('/privacy.html')),
            const Divider(height: 24),
            _SettingsAction(
                icon: Icons.description_outlined,
                title: '서비스 이용약관',
                onTap: () => openPublicPage('/terms.html')),
          ])),
          const SizedBox(height: 24),
          const Text('작은 기록이 모이는 곳, paylog',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
        ],
      );
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction(
      {required this.icon,
      required this.title,
      required this.onTap,
      this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: title,
      hint: subtitle,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 21, color: AppColors.accent)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted))
                    ],
                  ])),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.muted),
            ])),
      ));
}
