import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/bento_card.dart';
import '../auth/auth_session.dart';
import 'household_session.dart';

class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});
  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(firebaseSessionProvider).initialize();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(firebaseSessionProvider);
    final session = ref.watch(householdSessionProvider);
    if (auth.user == null) {
      return Center(
          child: FilledButton(
              onPressed: () => context.go('/sign-in'),
              child: const Text('로그인하고 가계부 시작하기')));
    }
    final home = session.household;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('함께 쓰는 가계부', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('가계부를 만들거나 초대 코드로 참여하세요. 참여 인원 제한은 없어요.'),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          onPressed: session.busy ? null : session.load,
          icon: const Icon(Icons.refresh),
          label: const Text('가계부 새로고침')),
      if (session.busy) const LinearProgressIndicator(),
      if (session.error != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(session.error!))),
      if (session.loaded && home == null) ...[
        BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('새 가계부 만들기'),
          const SizedBox(height: 12),
          TextField(
              controller: _name,
              enabled: !session.busy,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '가계부 이름')),
          FilledButton(
              onPressed: session.busy ? null : () => session.create(_name.text),
              child: const Text('가계부 만들기')),
        ])),
        const SizedBox(height: 16),
        BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('초대받은 가계부 참여'),
          const SizedBox(height: 12),
          TextField(
              controller: _code,
              enabled: !session.busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: '초대 코드')),
          FilledButton(
              onPressed: session.busy
                  ? null
                  : () async {
                      await session.join(_code.text);
                      if (mounted && session.household != null) _code.clear();
                    },
              child: const Text('코드로 참여하기')),
        ])),
      ],
      if (home != null) ...[
        BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(home.name),
          TextButton(
              onPressed: () => context.go('/'), child: const Text('가계부 열기')),
          const SizedBox(height: 12),
          const Text(
              '새 초대 코드는 약 24시간 동안 여러 사람이 사용할 수 있어요. 이 코드를 받은 사람은 같은 가계부를 보고 수정할 수 있으니 믿을 수 있는 사람에게만 전달하세요.'),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: session.busy ? null : session.makeInvite,
              child: Text(
                  session.invitation == null ? '초대 코드 만들기' : '초대 코드 다시 만들기')),
          if (session.invitation != null) ...[
            const SizedBox(height: 12),
            SelectableText(session.invitation!.code),
            Text('만료: ${session.invitation!.expiresAt.toLocal()}'),
            Wrap(spacing: 8, children: [
              TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await Clipboard.setData(
                          ClipboardData(text: session.invitation!.code));
                      if (mounted) {
                        messenger.showSnackBar(
                            const SnackBar(content: Text('초대 코드를 복사했어요.')));
                      }
                    } catch (_) {
                      if (mounted) {
                        messenger.showSnackBar(const SnackBar(
                            content: Text('코드를 길게 눌러 직접 복사해 주세요.')));
                      }
                    }
                  },
                  child: const Text('초대 코드 복사')),
              TextButton(
                  onPressed: session.busy ? null : session.revoke,
                  child: const Text('이 초대 코드 폐기')),
            ]),
            const Text(
                '새로고침하면 코드 원문은 지워져요. 필요하면 다시 만드세요. 이전에 따로 만든 코드는 폐기하거나 만료되기 전까지 유효할 수 있어요.'),
          ],
        ])),
        const SizedBox(height: 16),
        BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('참여 중인 멤버'),
          ...session.people.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.username),
              subtitle: Text(p.role == 'owner' ? '가계부 만든 사람' : '공동 편집 멤버'))),
          if (session.hasMore)
            TextButton(
                onPressed: session.busy ? null : session.more,
                child: const Text('멤버 더 보기')),
        ])),
      ],
    ]);
  }
}
