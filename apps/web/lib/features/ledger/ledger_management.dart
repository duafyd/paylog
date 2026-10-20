import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../google_connection/google_oauth.dart';
import '../transactions/transaction.dart';
import 'sheets_ledger_repository.dart';

const managementHeaders = <String, List<String>>{
  'Members': memberHeaders,
  'Cards': [
    'id',
    'householdId',
    'issuer',
    'senderAllowlist',
    'maskedIdentifier',
    'memberId',
    'enabled',
    'createdAt'
  ],
  'Categories': [
    'id',
    'householdId',
    'name',
    'icon',
    'type',
    'sortOrder',
    'enabled'
  ],
  'Devices': [
    'id',
    'householdId',
    'memberId',
    'platform',
    'tokenHash',
    'enabled',
    'lastSeenAt',
    'createdAt'
  ],
  'Review': [
    'id',
    'key',
    'householdId',
    'deviceId',
    'reason',
    'candidate',
    'createdAt',
    'resolvedAt',
    'resolution'
  ],
};

class ManagementRow {
  const ManagementRow(this.values, this.revision);
  final Map<String, String> values;
  final String revision;
}

String _hash(List<dynamic> cells, int length) => sha256
    .convert(utf8.encode(jsonEncode(List.generate(
        length, (i) => i < cells.length ? cells[i].toString() : ''))))
    .toString();

class LedgerManagement {
  LedgerManagement(this.repository);
  final SheetsLedgerRepository repository;
  String get household => repository.ledgerMembers.isEmpty ? '' : _household;
  String _household = '';
  Future<Map<String, dynamic>> _request(String path,
          {String method = 'GET', Object? body, Map<String, String>? query}) =>
      repository.api.request(repository.token(), 'sheets.googleapis.com',
          '/v4/spreadsheets/${repository.sheetId}$path',
          method: method, body: body, query: query);
  Future<void> _owner() async {
    await repository.refresh();
    if (!repository.canWrite || repository.actor?.role != 'owner') {
      throw const ConnectionFailure('관리 기능은 활성 소유자 계정으로 사용할 수 있어요.');
    }
    final data = await _request('/values/Members!A1:H',
        query: {'valueRenderOption': 'UNFORMATTED_VALUE'});
    final rows = data['values'] as List;
    _household = '${rows[1][1]}';
  }

  Future<List<ManagementRow>> list(String name) async {
    await _owner();
    final rows = await _rows(name);
    return rows.skip(1).where((r) => (r as List).isNotEmpty).map((r) {
      final cells = r as List, header = managementHeaders[name]!;
      final values = {
        for (var i = 0; i < header.length; i++)
          header[i]: i < cells.length ? '${cells[i]}' : ''
      };
      if (values['householdId'] != _household) {
        throw const ConnectionFailure('다른 가계부의 관리 행이 섞여 있어요.');
      }
      return ManagementRow(values, _hash(cells, header.length));
    }).toList();
  }

  Future<List<dynamic>> _rows(String name) async {
    final header = managementHeaders[name];
    if (header == null) throw ArgumentError('Unknown table');
    final response = await _request('/values/$name!A1:Z',
        query: {'valueRenderOption': 'UNFORMATTED_VALUE'});
    final rows = response['values'] as List? ?? [];
    if (rows.isEmpty || jsonEncode(rows.first) != jsonEncode(header)) {
      throw const ConnectionFailure(
          '관리 탭 헤더가 없거나 달라요. SMS 관리 탭 준비 절차를 확인해 주세요.');
    }
    return rows;
  }

  Future<void> save(String name, Map<String, String> values,
      {ManagementRow? original}) async {
    await _owner();
    final header = managementHeaders[name]!;
    final rows = await _rows(name);
    final id = original?.values['id'] ?? const Uuid().v4();
    final matches = [
      for (var i = 1; i < rows.length; i++)
        if ((rows[i] as List).isNotEmpty && '${rows[i][0]}' == id) i
    ];
    if (original != null &&
        (matches.length != 1 ||
            _hash(rows[matches.single] as List, header.length) !=
                original.revision)) {
      throw const ConnectionFailure('다른 곳에서 변경됐어요. 목록을 다시 불러와 주세요.');
    }
    if (original == null && !['Cards', 'Categories'].contains(name)) {
      throw const ConnectionFailure('이 탭은 앱에서 새 항목을 만들 수 없어요.');
    }
    final next = {
      ...?original?.values,
      ...values,
      'id': id,
      'householdId': _household
    };
    if (next.values.any((v) => v.length > 4096)) {
      throw const ConnectionFailure('입력 길이를 확인해 주세요.');
    }
    if (name == 'Members') {
      if (next['displayName']!.trim().isEmpty ||
          !['owner', 'editor', 'viewer'].contains(next['role']) ||
          !['true', 'false'].contains(next['active'])) {
        throw const ConnectionFailure('멤버 이름·역할·상태를 확인해 주세요.');
      }
      if (original!.values['role'] == 'owner' &&
          original.values['active'] == 'true' &&
          (next['role'] != 'owner' || next['active'] != 'true') &&
          repository.ledgerMembers
                  .where((m) => m.active && m.role == 'owner')
                  .length <=
              1) {
        throw const ConnectionFailure('마지막 활성 소유자는 해제할 수 없어요.');
      }
      for (final key in ['googleSubject', 'email', 'joinedAt']) {
        next[key] = original.values[key]!;
      }
    } else if (name == 'Cards') {
      if (next['issuer']!.trim().isEmpty ||
          next['senderAllowlist']!.trim().isEmpty ||
          next['maskedIdentifier']!.trim().isEmpty ||
          !repository.ledgerMembers
              .any((m) => m.active && m.id == next['memberId']) ||
          !['true', 'false'].contains(next['enabled'])) {
        throw const ConnectionFailure('카드·실제 발신번호·멤버 UUID·활성 상태를 확인해 주세요.');
      }
      next['createdAt'] =
          original?.values['createdAt'] ?? seoulIso(seoulTime(DateTime.now()));
    } else if (name == 'Categories') {
      if (next['name']!.trim().isEmpty ||
          !['expense', 'income'].contains(next['type']) ||
          !['true', 'false'].contains(next['enabled']) ||
          int.tryParse(next['sortOrder'] ?? '') == null ||
          !categories.any((c) => c.id == next['icon'])) {
        throw const ConnectionFailure('이름·구분·정렬 숫자·아이콘 키·활성 상태를 확인해 주세요.');
      }
      if (original != null && original.values['type'] != next['type']) {
        throw const ConnectionFailure(
            '기존 카테고리의 수입/지출 구분은 변경할 수 없어요. 새로 추가해 주세요.');
      }
    } else if (name == 'Devices') {
      if (!['true', 'false'].contains(next['enabled'])) {
        throw const ConnectionFailure('활성 상태를 확인해 주세요.');
      }
      final enabled = next['enabled']!;
      next
        ..clear()
        ..addAll(original!.values)
        ..['enabled'] = enabled;
    } else if (name == 'Review') {
      final resolution = next['resolution'] ?? '';
      if (original!.values['resolvedAt']!.isNotEmpty) {
        throw const ConnectionFailure('이미 처리한 검토 항목입니다.');
      }
      if (resolution != 'ignored' &&
          !repository.readAll().any((t) => t.id == resolution)) {
        throw const ConnectionFailure('ignored 또는 수동 등록한 거래 UUID를 입력하세요.');
      }
      next
        ..clear()
        ..addAll(original.values)
        ..['resolution'] = resolution
        ..['resolvedAt'] = seoulIso(seoulTime(DateTime.now()));
    }
    final cells = header.map((h) => next[h] ?? '').toList();
    // Ambiguous admin writes require explicit reload/review; never retry automatically.
    try {
      if (original == null) {
        await _request('/values/$name!A1:append', method: 'POST', query: {
          'valueInputOption': 'RAW',
          'insertDataOption': 'INSERT_ROWS'
        }, body: {
          'values': [cells]
        });
      } else {
        await _request('/values:batchUpdate', method: 'POST', body: {
          'valueInputOption': 'RAW',
          'data': [
            {
              'range': '$name!A${matches.single + 1}',
              'values': [cells]
            }
          ]
        });
      }
    } catch (_) {
      throw const ConnectionFailure(
          '변경 결과가 불명확할 수 있어요. 목록과 시트를 다시 확인한 후 처리하세요.');
    }
    final confirmed = await _rows(name);
    if (!confirmed.skip(1).any((r) =>
        _hash(r as List, header.length) == _hash(cells, header.length))) {
      throw const ConnectionFailure('변경 재조회가 일치하지 않아요. 시트를 확인해 주세요.');
    }
  }
}
