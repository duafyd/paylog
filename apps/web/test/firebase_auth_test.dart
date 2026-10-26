import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/app/app.dart';
import 'package:paylog/features/auth/auth_port.dart';
import 'package:paylog/features/auth/auth_session.dart';
import 'package:paylog/features/auth/username.dart';
import 'package:paylog/features/transactions/transaction_repository.dart';
import 'widget_test.dart' show mount;

const first = AuthIdentity(uid: 'first', username: 'family_one');
const second = AuthIdentity(uid: 'second', username: 'family_two');

class FakeAuth implements AuthPort {
  final events = StreamController<AuthIdentity?>.broadcast(sync: true);
  AuthIdentity? restored;
  Completer<AuthIdentity?>? pendingInit;
  Completer<AuthIdentity>? pendingLogin;
  AuthFailure? loginFailure;
  bool logoutFails = false;
  int initializations = 0;
  int logins = 0;
  int logouts = 0;
  int registrations = 0;
  String? requestedUsername;
  @override
  Stream<AuthIdentity?> get changes => events.stream;
  @override
  Future<AuthIdentity?> initialize() async {
    initializations++;
    return pendingInit == null ? restored : await pendingInit!.future;
  }

  @override
  Future<AuthIdentity> signIn(String username, String password) async {
    requestedUsername = username;
    logins++;
    if (loginFailure != null) throw loginFailure!;
    return pendingLogin == null ? first : await pendingLogin!.future;
  }

  @override
  Future<AuthIdentity> register(String username, String password) async {
    registrations++;
    requestedUsername = username;
    if (loginFailure != null) throw loginFailure!;
    return pendingLogin == null ? first : await pendingLogin!.future;
  }

  @override
  Future<void> signOut() async {
    logouts++;
    if (logoutFails) throw StateError('private SDK details must not reach UI');
  }
}

void main() {
  test('blocked initialization times out without accepting a late identity',
      () async {
    final port = FakeAuth()..pendingInit = Completer<AuthIdentity?>();
    final session = AuthSession(port,
        initializationTimeout: const Duration(milliseconds: 1));
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    await session.initialize();
    expect(session.busy, false);
    expect(session.ready, false);
    expect(session.error, isNotNull);
    port.pendingInit!.complete(first);
    await Future<void>.delayed(Duration.zero);
    expect(session.user, isNull);
  });

  test('initialization and credential requests cannot be duplicated', () async {
    final port = FakeAuth()..pendingInit = Completer<AuthIdentity?>();
    final session = AuthSession(port);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    final initializing = session.initialize();
    await session.initialize();
    await session.signIn('family_one', 'test-password-only');
    expect(port.initializations, 1);
    expect(port.logins, 0);
    port.pendingInit!.complete(null);
    await initializing;
    port.pendingLogin = Completer<AuthIdentity>();
    final signingIn = session.signIn('family_one', 'test-password-only');
    await session.signIn('family_one', 'test-password-only');
    expect(port.logins, 1);
    expect(session.user, isNull);
    port.pendingLogin!.complete(first);
    await signingIn;
    expect(session.user?.uid, 'first');
    expect(session.busy, false);
  });
  test('restoration, identity change and signout clear identity-specific state',
      () async {
    final port = FakeAuth()..restored = first;
    var boundaries = 0;
    final session = AuthSession(port, onIdentityChanged: () => boundaries++);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    await session.initialize();
    expect(boundaries, 1);
    port.events.add(first);
    expect(boundaries, 1);
    port.events.add(second);
    expect(session.user?.uid, 'second');
    expect(boundaries, 2);
    await session.signOut();
    expect(session.user, isNull);
    expect(boundaries, 3);
  });
  test('wrong credentials and disabled password provider stay signed out',
      () async {
    final port = FakeAuth();
    final session = AuthSession(port);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    await session.initialize();
    for (final code in [
      'wrong-password',
      'user-not-found',
      'invalid-credential',
      'operation-not-allowed'
    ]) {
      port.loginFailure = AuthFailure(code);
      await session.signIn('family_one', 'test-password-only');
      expect(session.user, isNull);
      expect(session.busy, false);
      expect(session.error, authErrorMessage(code));
    }
  });
  test('failed signout cannot display a successful signout or SDK details',
      () async {
    final port = FakeAuth()
      ..restored = first
      ..logoutFails = true;
    final session = AuthSession(port);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    await session.initialize();
    await session.signOut();
    expect(session.user?.uid, 'first');
    expect(session.error, '로그아웃하지 못했어요. 다시 시도해 주세요.');
    expect(session.error, isNot(contains('private')));
  });
  test('auth stream error fails closed and can be initialized again', () async {
    final port = FakeAuth()..restored = first;
    final session = AuthSession(port);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    await session.initialize();
    port.events.addError(StateError('sensitive SDK failure'));
    expect(session.user, isNull);
    expect(session.ready, false);
    expect(session.error, isNot(contains('sensitive')));
    port.restored = null;
    await session.initialize();
    expect(session.ready, true);
    expect(session.user, isNull);
  });
  test('late completion after disposal cannot publish identity', () async {
    final port = FakeAuth()..pendingInit = Completer<AuthIdentity?>();
    final session = AuthSession(port);
    final future = session.initialize();
    session.dispose();
    port.pendingInit!.complete(first);
    await future;
    expect(session.user, isNull);
    await port.events.close();
  });
  test('Firebase identity transition discards the active legacy repository',
      () async {
    final port = FakeAuth();
    final container = ProviderContainer(
        overrides: [firebaseAuthPortProvider.overrideWithValue(port)]);
    addTearDown(container.dispose);
    addTearDown(port.events.close);
    final previousDemo = container.read(demoRepositoryProvider);
    final old = InMemoryTransactionRepository(DateTime(2026, 1));
    container.read(activeRepositoryProvider.notifier).state = old;
    final session = container.read(firebaseSessionProvider);
    await session.initialize();
    await session.signIn('family_one', 'test-password-only');
    expect(container.read(activeRepositoryProvider), isNull);
    expect(container.read(demoRepositoryProvider), isNot(same(previousDemo)));
    expect(container.read(transactionRepositoryProvider), isNot(same(old)));
  });

  test('username normalization has no ambiguous aliases or email input', () {
    expect(
        usernameAddress(' Family_One '), 'family_one@accounts.paylog.invalid');
    expect(usernameFromAddress('family_one@accounts.paylog.invalid'),
        'family_one');
    expect(usernameFromAddress('person@gmail.com'), isNull);
    for (final value in [
      'abc',
      '1abcd',
      '한글아이디',
      'a.bcd',
      'abcd@domain.com',
      'aaaa\nbbbb',
      'a' * 21
    ]) {
      expect(() => usernameAddress(value), throwsA(isA<AuthFailure>()));
    }
  });
  test('validation does not submit passwords or create duplicate accounts',
      () async {
    final port = FakeAuth();
    final session = AuthSession(port);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    await session.initialize();
    await session.register('bad@id', 'test-password-only');
    await session.register('family_one', 'short');
    expect(port.registrations, 0);
    port.pendingLogin = Completer<AuthIdentity>();
    final registration = session.register(' Family_One ', 'test-password-only');
    await session.register('family_one', 'test-password-only');
    expect(port.registrations, 1);
    expect(port.requestedUsername, 'family_one');
    port.pendingLogin!.complete(first);
    await registration;
    expect(session.user?.username, 'family_one');
  });
  test('duplicate ID errors never expose raw backend exception details',
      () async {
    final port = FakeAuth()
      ..loginFailure = const AuthFailure('email-already-in-use');
    final session = AuthSession(port);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    await session.initialize();
    await session.register('family_one', 'test-password-only');
    expect(session.user, isNull);
    expect(session.error, authErrorMessage('email-already-in-use'));
    expect(
        authErrorMessage('user-not-found'), authErrorMessage('wrong-password'));
  });
  testWidgets(
      'mobile ID login handles wrong password and clears credentials after success',
      (tester) async {
    final port = FakeAuth()
      ..loginFailure = const AuthFailure('invalid-credential');
    addTearDown(port.events.close);
    final container = await mount(tester, width: 360, scale: 1.6, auth: port);
    container.read(routerProvider).go('/sign-in');
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'family_one');
    await tester.enterText(fields.at(1), 'test-password-only');
    final submit = find.widgetWithText(FilledButton, '로그인');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(authErrorMessage('invalid-credential')), findsOneWidget);
    expect(find.text('로그인 완료'), findsNothing);
    port.loginFailure = null;
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('로그인 완료'), findsOneWidget);
    expect(find.text('family_one님'), findsOneWidget);
    await tester.ensureVisible(find.text('로그아웃'));
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'registration requires matching password confirmation and no Google account',
      (tester) async {
    final port = FakeAuth();
    addTearDown(port.events.close);
    final container = await mount(tester, width: 393, auth: port);
    container.read(routerProvider).go('/sign-in');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('처음이라면 회원가입'));
    await tester.tap(find.text('처음이라면 회원가입'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'family_one');
    await tester.enterText(fields.at(1), 'test-password-only');
    await tester.enterText(fields.at(2), 'different-password');
    final submit = find.widgetWithText(FilledButton, '가입하고 시작하기');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
    expect(port.registrations, 0);
    await tester.enterText(fields.at(2), 'test-password-only');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(port.registrations, 1);
    expect(find.text('family_one님'), findsOneWidget);
    expect(find.text('Google로 로그인'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
