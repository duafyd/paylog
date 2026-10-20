import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paylog/features/google_connection/google_connection.dart';
import 'package:paylog/features/google_connection/google_oauth.dart';
import 'package:paylog/features/google_connection/sheets_probe.dart';

const sheetId = 'exampleSheetIdentifier1234567890';
final now = DateTime.utc(2026, 10, 20);
http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

class FakeOAuth implements GoogleOAuthPort {
  final scopes = <String>[];
  bool failRevoke = false;
  Completer<OAuthGrant>? pending;
  @override
  Future<void> initialize() async {}
  @override
  Future<OAuthGrant> authorize(String scope) async {
    scopes.add(scope);
    return pending?.future ??
        OAuthGrant('test-only-token', now.add(const Duration(hours: 1)));
  }

  @override
  Future<void> revoke(String token) async {
    if (failRevoke) throw StateError('revoke failed');
  }
}

void main() {
  test('시트 ID는 Google URL만 받아들이고 임의 호스트와 경로 주입을 거부한다', () {
    expect(parseSpreadsheetId(sheetId), sheetId);
    expect(
        parseSpreadsheetId(
            'https://docs.google.com/spreadsheets/d/$sheetId/edit#gid=0'),
        sheetId);
    for (final value in [
      'https://evil.example/$sheetId',
      'https://docs.google.com.evil.example/spreadsheets/d/$sheetId/edit',
      '../$sheetId',
      'short',
      'http://docs.google.com/spreadsheets/d/$sheetId/edit'
    ]) {
      expect(
          () => parseSpreadsheetId(value), throwsA(isA<ConnectionFailure>()));
    }
  });
  test('기존 시트 검사는 인증된 GET만 사용하고 헤더와 데이터 행 수를 검증한다', () async {
    final requests = <http.Request>[];
    final api = GoogleApi(MockClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer test-only-token');
      expect(request.url.host, 'sheets.googleapis.com');
      if (request.url.path.contains('/values/')) {
        expect(request.url.queryParameters['valueRenderOption'],
            'UNFORMATTED_VALUE');
        return json({
          'values': [
            transactionHeaders,
            ['row1'],
            []
          ]
        });
      }
      return json({
        'properties': {'title': '검증 시트'}
      });
    }));
    final result = await SheetsProbe(api).inspect('test-only-token', sheetId);
    expect(result.title, '검증 시트');
    expect(result.transactionCount, 1);
    expect(requests.map((r) => r.method), everyElement('GET'));
  });
  test('잘못된 Transactions 헤더는 성공으로 처리하지 않는다', () async {
    final probe = SheetsProbe(GoogleApi(
        MockClient((request) async => request.url.path.contains('/values/')
            ? json({
                'values': [
                  ['wrong', 'header']
                ]
              })
            : json({
                'properties': {'title': '다른 시트'}
              }))));
    await expectLater(probe.inspect('test-only-token', sheetId),
        throwsA(isA<ConnectionFailure>()));
  });
  test('전용 시트를 생성하고 RAW 거래·서울 시각을 저장한 뒤 같은 UUID와 금액을 재조회한다', () async {
    List<dynamic>? inserted;
    final methods = <String>[];
    final probe = SheetsProbe(GoogleApi(MockClient((request) async {
      methods.add(request.method);
      if (request.method == 'POST' && request.url.path == '/v4/spreadsheets') {
        final body = jsonDecode(request.body) as Map;
        expect(body['properties']['timeZone'], 'Asia/Seoul');
        return json({'spreadsheetId': sheetId});
      }
      if (request.method == 'POST') {
        expect(request.url.queryParameters['valueInputOption'], 'RAW');
        inserted = (jsonDecode(request.body) as Map)['values'] as List;
        expect(inserted![0], transactionHeaders);
        expect(inserted![1][3], 1000);
        expect(inserted![1][4], endsWith('+09:00'));
        expect(inserted![1][16], 'google-subject');
        return json({
          'updates': {'updatedRows': 2}
        });
      }
      return json({'values': inserted});
    })));
    String? created;
    final result = await probe.createAndVerify(
        'test-only-token', 'google-subject',
        onCreated: (id) => created = id);
    expect(created, sheetId);
    expect(result.transactionCount, 1);
    expect(methods, ['POST', 'POST', 'GET']);
  });
  test('쓰기 실패 시 생성 ID를 남기며 같은 쓰기를 자동 재시도하지 않는다', () async {
    var writes = 0;
    String? created;
    final probe = SheetsProbe(GoogleApi(MockClient((request) async {
      if (request.url.path == '/v4/spreadsheets') {
        return json({'spreadsheetId': sheetId});
      }
      writes++;
      return json({'error': 'DO_NOT_ECHO_PRIVATE_RESPONSE'}, 500);
    })));
    await expectLater(
        probe.createAndVerify('test-only-token', 'sub',
            onCreated: (id) => created = id),
        throwsA(isA<ConnectionFailure>().having((e) => e.message,
            'sanitized message', isNot(contains('DO_NOT_ECHO')))));
    expect(created, sheetId);
    expect(writes, 1);
  });
  for (final status in [401, 403, 404, 429, 503]) {
    test('HTTP $status 오류를 안전하게 분류한다', () async {
      final api = GoogleApi(
          MockClient((_) async => json({'sensitive': 'PRIVATE'}, status)));
      await expectLater(
          api.request('test-only-token', 'sheets.googleapis.com',
              '/v4/spreadsheets/$sheetId'),
          throwsA(isA<ConnectionFailure>()
              .having((e) => e.reauthenticate, 'reauthenticate', status == 401)
              .having(
                  (e) => e.message, 'message', isNot(contains('PRIVATE')))));
    });
  }
  test('로그인과 Sheets 동의를 분리하고 같은 계정만 Sheets 세션에 연결한다', () async {
    final oauth = FakeOAuth();
    var subject = 'account-a';
    final controller = GoogleConnection(
        oauth,
        GoogleApi(MockClient((_) async => json({
              'sub': subject,
              'email': 'demo@example.com',
              'email_verified': true,
              'name': '테스트'
            }))),
        configured: true,
        clock: () => now);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.signIn();
    expect(oauth.scopes, [identityScope]);
    expect(controller.sheetsAuthorized, isFalse);
    subject = 'account-b';
    await controller.authorizeSheets();
    expect(controller.error, contains('다른 계정'));
    expect(controller.sheetsAuthorized, isFalse);
    subject = 'account-a';
    await controller.authorizeSheets();
    expect(controller.error, isNull);
    expect(controller.sheetsAuthorized, isTrue);
    expect(oauth.scopes.last, contains(sheetsScope));
  });
  test('만료된 Sheets 토큰으로 요청을 보내지 않는다', () async {
    var time = now;
    var requests = 0;
    final controller =
        GoogleConnection(FakeOAuth(), GoogleApi(MockClient((_) async {
      requests++;
      return json(
          {'sub': 'a', 'email': 'demo@example.com', 'email_verified': true});
    })), configured: true, clock: () => time);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.signIn();
    await controller.authorizeSheets();
    expect(requests, 2);
    time = now.add(const Duration(hours: 2));
    await controller.inspect(sheetId);
    expect(requests, 2);
    expect(controller.sheetsAuthorized, isFalse);
    expect(controller.error, contains('만료'));
  });
  test('중복 로그인 요청을 막고 철회 실패에도 로컬 토큰·계정은 제거한다', () async {
    final oauth = FakeOAuth()..pending = Completer<OAuthGrant>();
    final controller = GoogleConnection(
        oauth,
        GoogleApi(MockClient((_) async => json({
              'sub': 'a',
              'email': 'demo@example.com',
              'email_verified': true
            }))),
        configured: true,
        clock: () => now);
    addTearDown(controller.dispose);
    await controller.initialize();
    final signIn = controller.signIn();
    await controller.signIn();
    expect(oauth.scopes, hasLength(1));
    oauth.pending!.complete(
        OAuthGrant('test-only-token', now.add(const Duration(hours: 1))));
    await signIn;
    oauth.failRevoke = true;
    await controller.disconnect();
    expect(controller.profile, isNull);
    expect(controller.sheetsAuthorized, isFalse);
    expect(controller.error, contains('철회는 확인하지 못했어요'));
  });
}
