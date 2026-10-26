import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../platform/open_public_page.dart';
import '../theme/app_theme.dart';

/// Public service information stays available after the loading HTML is removed.
class ServiceIntro extends StatelessWidget {
  const ServiceIntro({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'paylog는 가족이 수입과 지출을 함께 기록하는 가계부예요. '
            'Google 계정을 연결하면 내가 접근할 수 있는 Google Sheets 원장에 '
            '기록을 저장하고, 달력과 통계로 확인할 수 있어요.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          TextButton.icon(
            onPressed: () => context.go('/sign-in'),
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Google 계정으로 시작'),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => openPublicPage('/privacy.html'),
                child: const Text('개인정보처리방침'),
              ),
              TextButton(
                onPressed: () => openPublicPage('/terms.html'),
                child: const Text('서비스 이용약관'),
              ),
            ],
          ),
        ],
      );
}
