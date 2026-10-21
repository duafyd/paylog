import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/bento_card.dart';
import '../google_connection/google_oauth.dart';
import '../transactions/transaction_repository.dart';
import 'sheets_ledger_repository.dart';
import 'ledger_management.dart';
import '../export/download.dart';

class ManagementScreen extends ConsumerStatefulWidget {
  const ManagementScreen({super.key});
  @override
  ConsumerState<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends ConsumerState<ManagementScreen> {
  String _table = 'Members';
  List<ManagementRow> _rows = [];
  String? _error;
  bool _busy = false;
  LedgerManagement? _service;
  Object? _bound;
  static const _editable = {
    'Members': ['displayName', 'role', 'active'],
    'Cards': [
      'issuer',
      'senderAllowlist',
      'maskedIdentifier',
      'memberId',
      'enabled'
    ],
    'Categories': ['name', 'icon', 'type', 'sortOrder', 'enabled'],
    'Devices': ['enabled'],
    'Review': ['resolution'],
  };
  @override
  void initState() {
    super.initState();
    final repository = ref.read(transactionRepositoryProvider);
    _bound = repository;
    if (repository is SheetsLedgerRepository) {
      _service = LedgerManagement(repository);
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (_busy || _service == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _rows = [];
    });
    try {
      final rows = await _service!.list(_table);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ConnectionFailure
            ? e.message
            : '목록을 읽지 못했어요. 탭 준비 절차와 Google 권한을 확인하세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ManagementRow? row) async {
    final table = _table;
    final fields = _editable[table]!;
    final controllers = {
      for (final f in fields)
        f: TextEditingController(
            text: row?.values[f] ??
                (['active', 'enabled'].contains(f)
                    ? 'true'
                    : f == 'type'
                        ? 'expense'
                        : f == 'sortOrder'
                            ? '0'
                            : f == 'icon'
                                ? 'other'
                                : ''))
    };
    final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('$table ${row == null ? '추가' : '변경'}'),
              content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'enabled/active: true 또는 false\nrole: owner/editor/viewer\nicon: food/groceries/cafe/transport/shopping/health/leisure/other/salary/bonus\nReview resolution: ignored 또는 확인된 수동 거래 UUID'),
                    ...fields.map((f) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                            controller: controllers[f],
                            maxLength: f == 'senderAllowlist' ? 500 : 160,
                            decoration: InputDecoration(labelText: f)))),
                  ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, {
                          for (final f in fields) f: controllers[f]!.text.trim()
                        }),
                    child: const Text('변경 저장'))
              ],
            ));
    // Dialog animations retain their TextFields until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
    if (values == null ||
        !mounted ||
        !identical(_bound, ref.read(transactionRepositoryProvider))) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service!.save(table, values, original: row);
      await ref.read(transactionsProvider.notifier).refresh();
      if (mounted) setState(() => _rows = []);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ConnectionFailure
            ? e.message
            : '변경 결과를 확인하지 못했어요. 목록과 시트를 확인하세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Deliberately require a reload after any attempted write; the old dialog
    // cannot repeat an uncertain create request.
  }

  Future<void> _connectAndroid() async {
    final members =
        _service!.repository.ledgerMembers.where((m) => m.active).toList();
    if (members.isEmpty) return;
    var memberId = members.first.id;
    final endpoint = TextEditingController();
    final chosen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Android 간편 연결'),
                content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          '이 휴대폰을 사용할 가족을 선택하세요. 기기 ID와 연결 키는 자동으로 만들고, 문자 발신번호는 등록된 카드에서 가져와요.'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          initialValue: memberId,
                          decoration:
                              const InputDecoration(labelText: '사용할 가족'),
                          items: members
                              .map((m) => DropdownMenuItem(
                                  value: m.id, child: Text(m.name)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) memberId = value;
                          }),
                      const SizedBox(height: 12),
                      TextField(
                          controller: endpoint,
                          maxLength: 512,
                          decoration: const InputDecoration(
                              labelText: '가족 문자 수집 서버 주소',
                              hintText:
                                  'https://script.google.com/macros/s/…/exec')),
                      const Text(
                          '서버 최초 배포와 카드 등록은 소유자가 먼저 준비해야 해요. 휴대폰마다 파일을 따로 만드세요. 파일에는 연결 키가 포함되므로 공개하거나 채팅에 올리지 마세요.'),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('연결 파일 만들기'))
                ]));
    final address = endpoint.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => endpoint.dispose());
    if (chosen != true ||
        !mounted ||
        !identical(_bound, ref.read(transactionRepositoryProvider))) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final contents =
          await _service!.createAndroidConnection(address, memberId);
      if (!mounted ||
          !identical(_bound, ref.read(transactionRepositoryProvider))) {
        return;
      }
      // A second explicit tap keeps mobile downloads inside a user gesture.
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('연결 파일 준비 완료'),
                  content: const Text(
                      '이 휴대폰에 파일을 저장한 뒤 문자 수집 앱에서 “연결 파일 선택”을 누르세요. 연결 후 다운로드한 파일은 삭제해 주세요. 분실하면 기기 목록에서 비활성화하고 새로 만들 수 있어요.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('닫기')),
                    FilledButton(
                        onPressed: () => downloadConnection(contents),
                        child: const Text('연결 파일 저장'))
                  ]));
      if (mounted) setState(() => _rows = []);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ConnectionFailure
            ? e.message
            : '연결 파일을 준비하지 못했어요. 기기 목록을 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(transactionRepositoryProvider);
    if (_service == null || !identical(_bound, repository)) {
      return const Center(child: Text('실제 Sheets 원장을 연결한 뒤 관리 화면을 다시 열어 주세요.'));
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('가계부 관리', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text(
          '소유자 전용 · Google 공유 권한은 Sheets 공유 메뉴에서 변경하세요. 카드 발신번호는 실제 번호만 입력하세요. Android는 간편 연결에서 기기를 자동 등록할 수 있어요.'),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
          initialValue: _table,
          items: managementHeaders.keys
              .map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(const {
                    'Members': '가족',
                    'Cards': '카드',
                    'Categories': '카테고리',
                    'Devices': '기기',
                    'Review': '검토함'
                  }[t]!)))
              .toList(),
          onChanged: _busy
              ? null
              : (value) {
                  setState(() => _table = value!);
                  _load();
                }),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('목록 새로고침')),
        if (_table == 'Devices')
          FilledButton.icon(
              onPressed: _busy ? null : _connectAndroid,
              icon: const Icon(Icons.phone_android),
              label: const Text('Android 간편 연결')),
        if (['Cards', 'Categories'].contains(_table))
          FilledButton.icon(
              onPressed: _busy ? null : () => _edit(null),
              icon: const Icon(Icons.add),
              label: const Text('새 항목'))
      ]),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(liveRegion: true, child: Text(_error!))),
      ..._rows.map((row) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: BentoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                ...row.values.entries
                    .where((e) => e.key != 'tokenHash' && e.key != 'key')
                    .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText('${e.key}: ${e.value}'))),
                OutlinedButton(
                    onPressed: _busy ? null : () => _edit(row),
                    child: Text(_table == 'Review' ? '검토 처리' : '변경')),
              ])))),
    ]);
  }
}
