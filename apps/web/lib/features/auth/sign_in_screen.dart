import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/platform/open_public_page.dart';
import '../../core/widgets/bento_card.dart';
import 'auth_session.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(firebaseSessionProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(firebaseSessionProvider);
    final user = session.user;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('우리 둘의 가계부 시작하기', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('각자 Google 계정으로 로그인해요. 로그인에 Google Sheets 권한은 요청하지 않아요.'),
      const SizedBox(height: 20),
      BentoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (user == null) ...[
            const Text('Google 계정으로 로그인',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: session.ready && !session.busy ? session.signIn : null,
              icon: const Icon(Icons.login),
              label: const Text('Google로 로그인'),
            ),
          ] else ...[
            const Text('로그인 완료',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            Text(user.name ?? 'Google 계정'),
            if (user.email != null) Text(user.email!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: session.busy ? null : session.signOut,
              child: const Text('로그아웃'),
            ),
          ],
          if (session.busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(semanticsLabel: '로그인 상태 확인 중'),
          ],
          if (session.error != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(session.error!)),
          ],
          if (!session.ready && !session.busy)
            TextButton(
                onPressed: session.initialize,
                child: const Text('로그인 다시 준비하기')),
        ]),
      ),
      const SizedBox(height: 16),
      const BentoCard(
          child: Text('현재는 새 로그인 연결 단계예요. 공동 가계부 저장 기능은 다음 단계에서 연결합니다. '
              '로그인만으로 샘플 기록이 저장되거나 기존 시트가 자동 이전되지는 않아요.')),
      const SizedBox(height: 16),
      const Text('이 탭에서는 새로고침 후에도 로그인을 유지해요. 공용 기기에서는 사용 후 로그아웃해 주세요. '
          'Safari와 홈 화면 웹앱은 각각 로그인이 필요할 수 있어요.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        TextButton(
            onPressed: () => openPublicPage('/privacy.html'),
            child: const Text('개인정보처리방침')),
        TextButton(
            onPressed: () => openPublicPage('/terms.html'),
            child: const Text('서비스 이용약관')),
      ]),
    ]);
  }
}
