import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../google_connection/google_oauth.dart';
import '../google_connection/sheets_probe.dart';
import '../transactions/transaction.dart';
import '../transactions/transaction_repository.dart';

const ledgerHeaders = [...transactionHeaders, 'paymentMethod'];
const memberHeaders = [
  'id',
  'householdId',
  'googleSubject',
  'email',
  'displayName',
  'role',
  'joinedAt',
  'active'
];
final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

DateTime? _readOccurredAt(String value) {
  final match = RegExp(
          r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$')
      .firstMatch(value);
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final year = parts[0], month = parts[1], day = parts[2];
  if (year < 1 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime.utc(year, month + 1, 0).day ||
      parts[3] > 23 ||
      parts[4] > 59 ||
      parts[5] > 59) {
    return null;
  }
  final offset = match.group(7)!;
  if (offset != 'Z') {
    final hour = int.parse(offset.substring(1, 3)),
        minute = int.parse(offset.substring(4));
    if (hour > 14 || minute > 59 || (hour == 14 && minute != 0)) return null;
  }
  return DateTime.tryParse(value);
}

class SheetsLedgerRepository extends TransactionRepository {
  SheetsLedgerRepository(
      {required this.api,
      required this.token,
      required this.subject,
      required String id})
      : sheetId = parseSpreadsheetId(id);
  final GoogleApi api;
  final String Function() token;
  final String subject;
  @override
  final String sheetId;
  @override
  String title = '';
  @override
  List<LedgerMember> ledgerMembers = [];
  @override
  LedgerMember? actor;
  List<BudgetCategory> _catalog = categories;
  @override
  List<BudgetCategory> get categoryCatalog => _catalog;
  String _household = '';
  bool _extended = false;
  final Set<String> _uncertain = {};
  final Map<String, List<dynamic>> _pendingChanges = {};
  final Map<String, int> _rowNumbers = {};
  String _revision(List<dynamic> row) => sha256
      .convert(utf8.encode(jsonEncode(
          List.generate(19, (i) => i < row.length ? row[i].toString() : ""))))
      .toString();
  final Map<String, List<dynamic>> _raw = {};
  List<BudgetTransaction> _items = [];
  @override
  int excludedCount = 0;
  @override
  bool get canWrite =>
      _extended && actor != null && actor!.active && actor!.role != 'viewer';
  @override
  List<BudgetTransaction> readAll() => List.unmodifiable(_items);

  Future<Map<String, dynamic>> _request(String path,
          {String method = 'GET', Object? body, Map<String, String>? query}) =>
      api.request(
          token(), 'sheets.googleapis.com', '/v4/spreadsheets/$sheetId$path',
          method: method, body: body, query: query);

  @override
  Future<void> refresh() async {
    // Publish the snapshot only after every table has passed validation.
    final metadata = await _request('',
        query: {'fields': 'properties(title),sheets(properties(title))'});
    final tabs = (metadata['sheets'] as List? ?? [])
        .map((s) => (s['properties'] as Map)['title']);
    final catalog = <BudgetCategory>[...categories];
    final categoryHouseholds = <String>{};
    if (tabs.contains('Categories')) {
      final categoryData = await _request('/values/Categories!A1:G',
          query: {'valueRenderOption': 'UNFORMATTED_VALUE'});
      final categoryRows = categoryData['values'] as List? ?? [];
      const header = [
        'id',
        'householdId',
        'name',
        'icon',
        'type',
        'sortOrder',
        'enabled'
      ];
      if (categoryRows.isEmpty ||
          jsonEncode(categoryRows.first) != jsonEncode(header)) {
        throw const ConnectionFailure('Categories 헤더가 올바르지 않아요.');
      }
      final seen = <String>{};
      for (final raw in categoryRows.skip(1)) {
        final r = raw as List;
        if (r.isEmpty) continue;
        if (r.length > 1) categoryHouseholds.add('${r[1]}');
        if (r.length < 7 ||
            !_uuid.hasMatch('${r[0]}') ||
            !seen.add('${r[0]}') ||
            '${r[2]}'.trim().isEmpty ||
            !['income', 'expense'].contains(r[4]) ||
            !['true', 'false'].contains('${r[6]}'.toLowerCase()) ||
            int.tryParse('${r[5]}') == null ||
            !categories.any((c) => c.id == r[3])) {
          throw const ConnectionFailure('Categories 행을 확인해 주세요.');
        }
        catalog.add(BudgetCategory(
            '${r[0]}',
            '${r[2]}',
            categories.firstWhere((c) => c.id == r[3]).icon,
            TransactionType.values.byName('${r[4]}'),
            enabled: '${r[6]}'.toLowerCase() == 'true',
            sortOrder: int.parse('${r[5]}')));
      }
    }
    final data = await _request('/values:batchGet', query: {
      'ranges': 'Members!A1:H',
      'valueRenderOption': 'UNFORMATTED_VALUE'
    });
    final ranges = data['valueRanges'] as List? ?? [];
    final memberRows = ranges.isEmpty
        ? <dynamic>[]
        : (ranges.first as Map)['values'] as List? ?? [];
    if (memberRows.isEmpty ||
        jsonEncode(memberRows.first) != jsonEncode(memberHeaders)) {
      throw const ConnectionFailure('Members 헤더가 맞지 않아요. 가계부 템플릿을 확인해 주세요.');
    }
    final people = <LedgerMember>[];
    final households = <String>{};
    final ids = <String>{};
    for (var index = 1; index < memberRows.length; index++) {
      final row = memberRows[index] as List;
      if (row.isEmpty || row.every((v) => '$v'.isEmpty)) continue;
      String cell(int i) => i < row.length ? '${row[i]}' : '';
      final id = cell(0),
          household = cell(1),
          role = cell(5),
          active = cell(7).toLowerCase();
      if (!_uuid.hasMatch(id) ||
          !_uuid.hasMatch(household) ||
          !ids.add(id) ||
          cell(4).trim().isEmpty ||
          !['owner', 'editor', 'viewer'].contains(role) ||
          !['true', 'false'].contains(active)) {
        throw ConnectionFailure(
            'Members ${index + 1}행을 해석하지 못했어요. ID·이름·역할·활성 상태를 확인해 주세요.');
      }
      households.add(household);
      people.add(LedgerMember(
          id: id,
          name: cell(4),
          subject: cell(2),
          email: cell(3),
          role: role,
          active: active == 'true'));
    }
    if (people.isEmpty || households.length != 1) {
      throw const ConnectionFailure('하나의 가계부에 속한 Members가 필요해요.');
    }
    if (categoryHouseholds.any((h) => h != households.single)) {
      throw const ConnectionFailure('Categories의 가계부 연결이 올바르지 않아요.');
    }
    final actors =
        people.where((m) => m.active && m.subject == subject).toList();
    if (actors.length > 1) {
      throw const ConnectionFailure('현재 Google 계정에 Members가 중복 연결되어 있어요.');
    }
    final transactions = await _request('/values/Transactions!A1:S',
        query: {'valueRenderOption': 'UNFORMATTED_VALUE'});
    final rows = transactions['values'] as List? ?? [];
    if (rows.isEmpty ||
        ![jsonEncode(transactionHeaders), jsonEncode(ledgerHeaders)]
            .contains(jsonEncode(rows.first))) {
      throw const ConnectionFailure(
          'Transactions 헤더가 맞지 않아요. 기존 시트는 자동 변경하지 않습니다.');
    }
    final extended = jsonEncode(rows.first) == jsonEncode(ledgerHeaders);
    final parsed = <BudgetTransaction>[];
    final raw = <String, List<dynamic>>{};
    final rowNumbers = <String, int>{};
    var excluded = 0;
    for (var index = 1; index < rows.length; index++) {
      final row = List<dynamic>.from(rows[index] as List);
      if (row.isEmpty || row.every((v) => '$v'.isEmpty)) continue;
      String cell(int i) => i < row.length ? '${row[i]}' : '';
      final id = cell(0);
      final amount = num.tryParse(cell(3));
      final date = _readOccurredAt(cell(4));
      final category =
          catalog.where((c) => c.id == cell(7) && c.type.name == cell(2));
      final member = people.where((m) => m.id == cell(8));
      if (!_uuid.hasMatch(id) ||
          raw.containsKey(id) ||
          cell(1) != households.single ||
          amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          amount > 999999999999 ||
          amount != amount.roundToDouble() ||
          date == null ||
          !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(cell(4)) ||
          category.isEmpty ||
          member.isEmpty ||
          cell(5).trim().isEmpty ||
          !['approved', 'cancelled', 'review_required'].contains(cell(11)) ||
          (extended && !paymentMethods.contains(cell(18)))) {
        throw ConnectionFailure(
            'Transactions ${index + 1}행이 유효하지 않아요. 중복 ID·금액·날짜·기본 카테고리·Members 연결을 확인해 주세요.');
      }
      raw[id] = row;
      rowNumbers[id] = index + 1;
      if (cell(17).isNotEmpty || cell(11) != 'approved') {
        excluded++;
        continue;
      }
      parsed.add(BudgetTransaction(
          id: id,
          revision: _revision(row),
          categoryDefinition: category.first,
          type: category.first.type,
          amount: amount.toInt(),
          occurredAt: seoulTime(date),
          merchant: cell(5),
          memo: cell(6),
          categoryId: cell(7),
          memberId: cell(8),
          member: member.first.name,
          paymentMethod: extended ? cell(18) : '미지정'));
    }
    _catalog = [
      ...categories,
      ...(catalog.skip(categories.length).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
    ];
    title = (metadata['properties'] as Map)['title'] as String;
    _household = households.single;
    _extended = extended;
    ledgerMembers = List.unmodifiable(people);
    actor = actors.isEmpty ? null : actors.single;
    _items = parsed;
    excludedCount = excluded;
    _rowNumbers
      ..clear()
      ..addAll(rowNumbers);
    _raw
      ..clear()
      ..addAll(raw);
  }

  Future<void> join({required String email, required String name}) async {
    if (name.trim().isEmpty || name.trim().length > 60) {
      throw const ConnectionFailure('이름은 1~60자로 입력해 주세요.');
    }
    await refresh();
    final all = ledgerMembers.where((m) => m.subject == subject).toList();
    if (all.isNotEmpty) {
      throw const ConnectionFailure('이미 등록된 계정이에요. 비활성 상태라면 소유자에게 문의해 주세요.');
    }
    final id = const Uuid().v5(Namespace.url.value, '$sheetId:$subject');
    final row = [
      id,
      _household,
      subject,
      email,
      name.trim(),
      'editor',
      seoulIso(seoulTime(DateTime.now())),
      true
    ];
    try {
      await _request('/values/Members!A1:H:append', method: 'POST', query: {
        'valueInputOption': 'RAW',
        'insertDataOption': 'INSERT_ROWS'
      }, body: {
        'values': [row]
      });
    } catch (_) {
      // Joining is never automatically repeated after an ambiguous append.
      throw const ConnectionFailure(
          '참여 결과를 확인하지 못했어요. 원장을 새로고침한 뒤 연결 상태를 확인해 주세요.');
    }
    await refresh();
  }

  @override
  Future<void> update(BudgetTransaction transaction) =>
      _change(transaction, false);
  @override
  Future<void> delete(BudgetTransaction transaction) =>
      _change(transaction, true);

  Future<void> _change(BudgetTransaction transaction, bool deleting) async {
    final key = '${transaction.id}:${deleting ? 'delete' : 'update'}';
    try {
      await refresh();
    } catch (_) {
      if (_pendingChanges.containsKey(key)) {
        throw const ConnectionFailure('변경 결과를 재조회하지 못했어요. 다시 확인해 주세요.',
            uncertainWrite: true);
      }
      rethrow;
    }
    final existing = _raw[transaction.id];
    final pending = _pendingChanges[key];
    if (pending != null) {
      if (existing != null && _revision(existing) == _revision(pending)) {
        _pendingChanges.remove(key);
        return;
      }
      throw const ConnectionFailure(
          '이전 변경 결과가 불명확해요. 시트를 확인해 주세요. 자동으로 다시 쓰지 않습니다.',
          uncertainWrite: true);
    }
    if (!canWrite) throw const ConnectionFailure('조회 전용 원장입니다.');
    if (existing == null ||
        transaction.revision.isEmpty ||
        _revision(existing) != transaction.revision) {
      throw const ConnectionFailure(
          '다른 곳에서 변경된 거래예요. 달력으로 돌아가 새로고침한 뒤 다시 열어 주세요.');
    }
    if (existing[11] != 'approved' || '${existing[17]}'.isNotEmpty) {
      throw const ConnectionFailure('취소·삭제된 거래는 변경할 수 없어요.');
    }
    if (!deleting &&
        (transaction.amount <= 0 ||
            transaction.amount > 999999999999 ||
            transaction.merchant.trim().isEmpty ||
            !ledgerMembers
                .any((m) => m.id == transaction.memberId && m.active) ||
            !categoryCatalog.any((c) =>
                c.id == transaction.categoryId &&
                c.type == transaction.type &&
                (c.enabled || existing[7] == c.id)) ||
            !paymentMethods.contains(transaction.paymentMethod))) {
      throw const ConnectionFailure('거래 정보를 확인해 주세요.');
    }
    final row = List<dynamic>.generate(
        19, (i) => i < existing.length ? existing[i] : '');
    final audit = seoulIso(seoulTime(DateTime.now()));
    if (deleting) {
      row[17] = audit;
    } else {
      row[2] = transaction.type.name;
      row[3] = transaction.amount;
      row[4] = seoulIso(transaction.occurredAt);
      row[5] = transaction.merchant;
      row[6] = transaction.memo;
      row[7] = transaction.categoryId;
      row[8] = transaction.memberId;
      row[18] = transaction.paymentMethod;
    }
    row[15] = audit;
    row[16] = actor!.id;
    _pendingChanges[key] = row;
    try {
      // Resolve UUID to a fresh row number on every operation. Sheets does not
      // offer compare-and-swap: the final read/write race remains best effort.
      await _request('/values:batchUpdate', method: 'POST', body: {
        'valueInputOption': 'RAW',
        'data': [
          {
            'range':
                'Transactions!A${_rowNumbers[transaction.id]}:S${_rowNumbers[transaction.id]}',
            'values': [row]
          }
        ]
      });
    } on ConnectionFailure catch (e) {
      if (!e.uncertainWrite) {
        _pendingChanges.remove(key);
        rethrow;
      }
      throw const ConnectionFailure('변경 결과를 확인하지 못했어요. 같은 화면에서 결과를 다시 확인해 주세요.',
          uncertainWrite: true);
    } catch (_) {
      throw const ConnectionFailure('변경 결과를 확인하지 못했어요. 같은 화면에서 결과를 다시 확인해 주세요.',
          uncertainWrite: true);
    }
    try {
      await refresh();
    } catch (_) {
      throw const ConnectionFailure('변경 후 재조회에 실패했어요. 결과를 다시 확인해 주세요.',
          uncertainWrite: true);
    }
    if (_raw[transaction.id] == null ||
        _revision(_raw[transaction.id]!) != _revision(row)) {
      throw const ConnectionFailure('변경한 거래가 일치하지 않아요. 시트를 확인해 주세요.',
          uncertainWrite: true);
    }
    _pendingChanges.remove(key);
  }

  @override
  Future<void> add(BudgetTransaction transaction) async {
    try {
      await refresh();
    } on ConnectionFailure catch (e) {
      if (_uncertain.contains(transaction.id)) {
        throw ConnectionFailure('이전 저장 결과를 재조회하지 못했어요. 시트를 확인해 주세요.',
            uncertainWrite: true, reauthenticate: e.reauthenticate);
      }
      rethrow;
    } catch (_) {
      if (_uncertain.contains(transaction.id)) {
        throw const ConnectionFailure('이전 저장 결과를 재조회하지 못했어요. 시트를 확인해 주세요.',
            uncertainWrite: true);
      }
      rethrow;
    } // Recheck current membership and schema before writing.
    bool matches(List<dynamic> row) =>
        row.length >= 19 &&
        row[1] == _household &&
        row[2] == transaction.type.name &&
        row[3] == transaction.amount &&
        row[4] == seoulIso(transaction.occurredAt) &&
        row[5] == transaction.merchant &&
        row[6] == transaction.memo &&
        row[7] == transaction.categoryId &&
        row[8] == transaction.memberId &&
        row[10] == 'manual' &&
        row[11] == 'approved' &&
        '${row[17]}'.isEmpty &&
        row[18] == transaction.paymentMethod;
    final existing = _raw[transaction.id];
    if (existing != null) {
      if (!matches(existing)) {
        throw const ConnectionFailure('같은 ID의 다른 거래가 이미 있어요. 덮어쓰지 않았습니다.');
      }
      _uncertain.remove(transaction.id);
      return;
    }
    if (_uncertain.contains(transaction.id)) {
      throw const ConnectionFailure(
          '이 거래의 이전 저장 결과가 불명확해요. 자동으로 다시 쓰지 않습니다. 시트를 직접 확인한 뒤 처리해 주세요.',
          uncertainWrite: true);
    }
    if (!canWrite) {
      throw const ConnectionFailure(
          '조회 전용 원장이에요. 활성 Members 연결·역할·paymentMethod 헤더를 확인해 주세요. 실제 권한은 Google 공유 설정이 결정합니다.');
    }
    if (transaction.amount <= 0 ||
        transaction.amount > 999999999999 ||
        transaction.merchant.trim().isEmpty ||
        !ledgerMembers.any((m) => m.id == transaction.memberId && m.active) ||
        !categoryCatalog.any((c) =>
            c.id == transaction.categoryId &&
            c.type == transaction.type &&
            c.enabled) ||
        !paymentMethods.contains(transaction.paymentMethod) ||
        !_uuid.hasMatch(transaction.id)) {
      throw const ConnectionFailure('거래 입력 또는 Members 연결이 올바르지 않아요.');
    }
    final audit = seoulIso(seoulTime(DateTime.now()));
    final row = [
      transaction.id,
      _household,
      transaction.type.name,
      transaction.amount,
      seoulIso(transaction.occurredAt),
      transaction.merchant,
      transaction.memo,
      transaction.categoryId,
      transaction.memberId,
      '',
      'manual',
      'approved',
      '',
      '',
      audit,
      audit,
      actor!.id,
      '',
      transaction.paymentMethod
    ];
    _uncertain.add(transaction.id);
    try {
      await _request('/values/Transactions!A1:S:append',
          method: 'POST',
          query: {
            'valueInputOption': 'RAW',
            'insertDataOption': 'INSERT_ROWS'
          },
          body: {
            'majorDimension': 'ROWS',
            'values': [row]
          });
    } on ConnectionFailure catch (failure) {
      // Definite Google rejections do not consume the draft ID.
      if (!failure.uncertainWrite) {
        _uncertain.remove(transaction.id);
        rethrow;
      }
      throw const ConnectionFailure(
          '저장 결과를 확인하지 못했어요. 같은 기록으로 결과를 다시 확인해 주세요. 자동으로 다시 쓰지 않습니다.',
          uncertainWrite: true);
    } catch (_) {
      throw const ConnectionFailure(
          '저장 결과를 확인하지 못했어요. 같은 기록으로 결과를 다시 확인해 주세요. 자동으로 다시 쓰지 않습니다.',
          uncertainWrite: true);
    }
    try {
      await refresh();
    } on ConnectionFailure catch (e) {
      throw ConnectionFailure('저장 후 재조회에 실패했어요. 같은 기록으로 결과를 다시 확인해 주세요.',
          uncertainWrite: true, reauthenticate: e.reauthenticate);
    } catch (_) {
      throw const ConnectionFailure('저장 후 재조회에 실패했어요. 같은 기록으로 결과를 다시 확인해 주세요.',
          uncertainWrite: true);
    }
    if (_raw[transaction.id] == null || !matches(_raw[transaction.id]!)) {
      throw const ConnectionFailure('저장한 거래를 다시 확인하지 못했어요. 시트를 확인해 주세요.',
          uncertainWrite: true);
    }
    _uncertain.remove(transaction.id);
  }
}

Future<String> createLedgerTemplate(GoogleApi api, String Function() token,
    {required String subject,
    required String email,
    required String name,
    required void Function(String) onCreated}) async {
  final created = await api.request(
      token(), 'sheets.googleapis.com', '/v4/spreadsheets',
      method: 'POST',
      body: {
        'properties': {'title': 'paylog 가계부', 'timeZone': 'Asia/Seoul'},
        'sheets': [
          {
            'properties': {'title': 'Transactions'}
          },
          {
            'properties': {'title': 'Members'}
          }
        ]
      });
  final id = parseSpreadsheetId(created['spreadsheetId'] as String);
  onCreated(id);
  final household = const Uuid().v4(), member = const Uuid().v4();
  await api.request(token(), 'sheets.googleapis.com',
      '/v4/spreadsheets/$id/values:batchUpdate',
      method: 'POST',
      body: {
        'valueInputOption': 'RAW',
        'data': [
          {
            'range': 'Transactions!A1:S1',
            'values': [ledgerHeaders]
          },
          {
            'range': 'Members!A1:H2',
            'values': [
              memberHeaders,
              [
                member,
                household,
                subject,
                email,
                name,
                'owner',
                seoulIso(seoulTime(DateTime.now())),
                true
              ]
            ]
          }
        ]
      });
  return id;
}
