import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/bento_card.dart';
import '../google_connection/google_oauth.dart';
import '../transactions/transaction_repository.dart';
import 'sheets_ledger_repository.dart';
import 'ledger_management.dart';

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
          '소유자 전용 · Google 공유 권한은 Sheets 공유 메뉴에서 변경하세요. 카드 발신번호는 실제 번호만 입력하세요. 기기 토큰은 GAS 관리 절차에서 발급하며 앱에 표시하지 않습니다.'),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
          initialValue: _table,
          items: managementHeaders.keys
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
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
