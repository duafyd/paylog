import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';
import 'google_connection.dart';
import '../ledger/ledger_widgets.dart';

class GoogleConnectionScreen extends ConsumerStatefulWidget {
  const GoogleConnectionScreen({super.key});
  @override
  ConsumerState<GoogleConnectionScreen> createState() =>
      _GoogleConnectionScreenState();
}

class _GoogleConnectionScreenState
    extends ConsumerState<GoogleConnectionScreen> {
  final _sheet = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(googleConnectionProvider).initialize();
    });
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('연결 테스트 시트를 만들까요?'),
              content: const Text(
                  'Google Drive에 새 스프레드시트 1개를 만들고 1,000원짜리 가상 거래를 저장한 뒤 다시 읽어 확인합니다. 기존 시트와 샘플 가계부는 바뀌지 않습니다. 생성한 시트는 자동 삭제하지 않습니다.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('새 시트 생성·검증'))
              ],
            ));
    if (confirmed == true && mounted) {
      await ref.read(googleConnectionProvider).createProbe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(googleConnectionProvider);
    final user = connection.profile;
    final result = connection.inspection;
    final sheetId = result?.id ?? connection.createdSheetId;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Google 연결 검증', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('로그인과 시트 접근을 단계별로 확인해요.',
          style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 20),
      const BentoCard(
          color: AppColors.accentSoft,
          child: Text(
              '접근 확인 PoC는 가계부와 별개로 동작해요. 아래에서 실제 원장을 연결하면 달력·등록·통계가 Sheets 모드로 전환됩니다. 샘플 거래는 복사하지 않습니다.')),
      const SizedBox(height: 16),
      if (!connection.configured)
        const BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader('웹 OAuth 설정이 필요해요'),
          SizedBox(height: 12),
          Text(
              'Google Cloud에서 웹 클라이언트 ID와 실행 주소를 등록한 뒤 GOOGLE_WEB_CLIENT_ID 빌드 설정으로 실행해 주세요. 자세한 절차는 docs/setup-google.md에 있습니다. 클라이언트 비밀키나 서비스 계정 키는 입력하지 않습니다.'),
        ])),
      if (connection.configured) ...[
        BentoCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SectionHeader('1. Google 계정 확인'),
              const SizedBox(height: 12),
              if (user != null) ...[
                Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                Text(user.email),
                const SizedBox(height: 12)
              ],
              if (!connection.ready)
                FilledButton(
                    onPressed:
                        connection.busy ? null : () => connection.initialize(),
                    child: Text(
                        connection.busy ? '로그인 모듈 준비 중…' : '로그인 모듈 다시 준비')),
              if (connection.ready && user == null)
                FilledButton(
                    onPressed:
                        connection.busy ? null : () => connection.signIn(),
                    child: const Text('Google 로그인')),
              if (user != null)
                OutlinedButton(
                    onPressed:
                        connection.busy ? null : () => connection.disconnect(),
                    child: const Text('Google 연결 해제')),
            ])),
        const SizedBox(height: 16),
        BentoCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SectionHeader('2. Sheets 권한 동의'),
              const SizedBox(height: 12),
              const Text(
                  '권한은 Google 계정이 접근할 수 있는 스프레드시트 전체에 적용됩니다. 실제 읽기·쓰기 권한은 각 시트의 Google 공유 설정이 결정해요.'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: user == null || connection.busy
                      ? null
                      : () => connection.authorizeSheets(),
                  child: Text(connection.sheetsAuthorized
                      ? 'Sheets 권한 다시 동의'
                      : 'Sheets 권한 요청')),
            ])),
        const SizedBox(height: 16),
        BentoCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SectionHeader('3. 접근 확인'),
              const SizedBox(height: 12),
              Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: TextField(
                      controller: _sheet,
                      enabled: !connection.busy,
                      maxLength: 300,
                      decoration: const InputDecoration(
                          labelText: '시트 ID 또는 Google Sheets URL'))),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: connection.busy || user == null
                      ? null
                      : () => connection.inspect(_sheet.text),
                  child: const Text('기존 시트 읽기 확인')),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: connection.busy || user == null ? null : _create,
                  child: const Text('전용 테스트 시트 생성·쓰기 확인')),
              const SizedBox(height: 8),
              const Text(
                  '기존 시트는 Transactions 헤더를 검사하고 행 수만 표시합니다. 쓰기 검사는 새 테스트 시트에서만 진행합니다.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ])),
      ],
      if (connection.busy)
        const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(semanticsLabel: 'Google 연결 확인 중')),
      if (connection.error != null)
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: BentoCard(
                child: Semantics(
                    liveRegion: true,
                    child: Text(connection.error!,
                        style: const TextStyle(color: AppColors.expense))))),
      if (result != null)
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: BentoCard(
                child: Semantics(
                    liveRegion: true,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader('접근 검증 완료'),
                          const SizedBox(height: 12),
                          Text(result.title),
                          Text(
                              'Transactions ${result.transactionCount}행을 확인했어요.'),
                          const Text('실제 가계부 연결 완료를 뜻하지 않습니다.',
                              style: TextStyle(color: AppColors.muted)),
                        ])))),
      if (sheetId != null)
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: BentoCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SectionHeader('확인할 시트'),
                  const SizedBox(height: 8),
                  SelectableText(
                      'https://docs.google.com/spreadsheets/d/$sheetId/edit'),
                  TextButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await Clipboard.setData(ClipboardData(
                              text:
                                  'https://docs.google.com/spreadsheets/d/$sheetId/edit'));
                          messenger.showSnackBar(
                              const SnackBar(content: Text('시트 주소를 복사했어요.')));
                        } catch (_) {
                          messenger.showSnackBar(const SnackBar(
                              content: Text('주소를 직접 선택해 복사해 주세요.')));
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('주소 복사')),
                  const Text('테스트 시트는 확인 후 Google Drive에서 직접 삭제해 주세요.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ]))),
      const SizedBox(height: 16),
      const LedgerConnectionPanel(),
    ]);
  }
}
