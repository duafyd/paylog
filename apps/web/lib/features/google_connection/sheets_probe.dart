import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'google_oauth.dart';

const transactionHeaders = [
  'id',
  'householdId',
  'type',
  'amount',
  'occurredAt',
  'merchant',
  'memo',
  'categoryId',
  'memberId',
  'cardId',
  'source',
  'status',
  'fingerprint',
  'originalTransactionId',
  'createdAt',
  'updatedAt',
  'updatedBy',
  'deletedAt',
];

String parseSpreadsheetId(String input) {
  final value = input.trim();
  final url = Uri.tryParse(value);
  String id = value;
  if (url != null && url.hasScheme) {
    if (url.scheme != 'https' || url.host != 'docs.google.com') {
      throw const ConnectionFailure('Google Sheets URL 또는 시트 ID를 입력해 주세요.');
    }
    final match = RegExp(r'^/spreadsheets/d/([A-Za-z0-9_-]+)(?:/|$)')
        .firstMatch(url.path);
    id = match?.group(1) ?? '';
  }
  if (!RegExp(r'^[A-Za-z0-9_-]{20,200}$').hasMatch(id)) {
    throw const ConnectionFailure('올바른 스프레드시트 ID를 입력해 주세요.');
  }
  return id;
}

class SheetInspection {
  const SheetInspection(this.id, this.title, this.transactionCount);
  final String id;
  final String title;
  final int transactionCount;
}

/// Direct Google API transport. Never accept arbitrary API hosts or echo bodies.
class GoogleApi {
  GoogleApi(this.client);
  final http.Client client;
  Future<Map<String, dynamic>> request(String token, String host, String path,
      {String method = 'GET', Map<String, String>? query, Object? body}) async {
    if (!['sheets.googleapis.com', 'openidconnect.googleapis.com']
        .contains(host)) {
      throw ArgumentError('Unsupported Google API host');
    }
    final uri = Uri.https(host, path, query);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final response = await (method == 'GET'
            ? client.get(uri, headers: headers)
            : client.post(uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 20));
    switch (response.statusCode) {
      case 401:
        throw const ConnectionFailure('인증이 만료되었어요. 다시 로그인해 주세요.',
            reauthenticate: true);
      case 403:
        throw const ConnectionFailure(
            'Google 권한 또는 시트 공유 권한이 없어요. 동의 범위·API 활성화·Viewer 여부를 확인해 주세요.');
      case 404:
        throw const ConnectionFailure(
            '시트 또는 Transactions 탭을 찾지 못했어요. ID와 공유 권한을 확인해 주세요.');
      case 429:
        throw const ConnectionFailure('Google 요청 한도를 초과했어요. 잠시 후 다시 시도해 주세요.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ConnectionFailure(
          'Google 요청에 실패했어요. 쓰기 요청은 반영됐을 수 있으니 자동 재시도하지 말고 시트를 확인해 주세요.');
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ConnectionFailure('Google 응답을 해석하지 못했어요.');
    }
  }
}

class SheetsProbe {
  SheetsProbe(this.api);
  final GoogleApi api;
  Future<SheetInspection> inspect(String token, String input) async {
    final id = parseSpreadsheetId(input);
    final metadata = await api.request(
        token, 'sheets.googleapis.com', '/v4/spreadsheets/$id', query: {
      'fields': 'spreadsheetId,properties(title),sheets(properties(title))'
    });
    final values = await api.request(token, 'sheets.googleapis.com',
        '/v4/spreadsheets/$id/values/Transactions!A1:R',
        query: {'valueRenderOption': 'UNFORMATTED_VALUE'});
    final rows = (values['values'] as List?) ?? [];
    if (rows.isEmpty ||
        jsonEncode(rows.first) != jsonEncode(transactionHeaders)) {
      throw const ConnectionFailure(
          'Transactions 헤더가 명세와 달라요. 전용 테스트 시트를 생성하거나 스키마를 확인해 주세요.');
    }
    return SheetInspection(
        id,
        (metadata['properties'] as Map)['title'] as String,
        rows.skip(1).where((r) => (r as List).isNotEmpty).length);
  }

  /// Only writes to a brand-new, explicitly requested probe sheet.
  Future<SheetInspection> createAndVerify(String token, String googleSubject,
      {required void Function(String id) onCreated}) async {
    final created = await api.request(
        token, 'sheets.googleapis.com', '/v4/spreadsheets',
        method: 'POST',
        body: {
          'properties': {'title': 'paylog 연결 테스트', 'timeZone': 'Asia/Seoul'},
          'sheets': [
            {
              'properties': {'title': 'Transactions'}
            }
          ],
        });
    final id = parseSpreadsheetId(created['spreadsheetId'] as String);
    onCreated(id); // Preserve the ID even if append/readback fails.
    final now = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 9))
        .toIso8601String()
        .replaceFirst('Z', '+09:00');
    final rowId = const Uuid().v4();
    final row = [
      rowId,
      'connection-probe',
      'expense',
      1000,
      now,
      '연결 확인용 가상 거래',
      '실제 가계부에 반영하지 않는 테스트 데이터',
      'other',
      googleSubject,
      '',
      'manual',
      'approved',
      '',
      '',
      now,
      now,
      googleSubject,
      ''
    ];
    await api.request(token, 'sheets.googleapis.com',
        '/v4/spreadsheets/$id/values/Transactions!A1:R:append',
        method: 'POST',
        query: {
          'valueInputOption': 'RAW',
          'insertDataOption': 'INSERT_ROWS'
        },
        body: {
          'majorDimension': 'ROWS',
          'values': [transactionHeaders, row]
        });
    final values = await api.request(token, 'sheets.googleapis.com',
        '/v4/spreadsheets/$id/values/Transactions!A1:R',
        query: {'valueRenderOption': 'UNFORMATTED_VALUE'});
    final rows = (values['values'] as List?) ?? [];
    if (rows.length != 2 ||
        (rows[1] as List).length < 4 ||
        rows[1][0] != rowId ||
        rows[1][3] != 1000) {
      throw const ConnectionFailure(
          '쓰기 후 읽기 검증이 일치하지 않아요. 생성한 테스트 시트를 확인해 주세요.');
    }
    return SheetInspection(id, 'paylog 연결 테스트', 1);
  }
}
