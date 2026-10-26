import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/app/app.dart';
import 'package:paylog/features/auth/auth_port.dart';
import 'package:paylog/features/auth/auth_session.dart';
import 'package:paylog/features/transactions/transaction_repository.dart';
import 'widget_test.dart' show mount;

const first =
    AuthIdentity(uid: 'first', email: 'first@example.com', name: '가족');
const second =
    AuthIdentity(uid: 'second', email: 'second@example.com', name: '배우자');

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
  @override
  Stream<AuthIdentity?> get changes => events.stream;
  @override
  Future<AuthIdentity?> initialize() async {
    initializations++;
    return pendingInit == null ? restored : await pendingInit!.future;
  }

  @override
  Future<AuthIdentity> signIn() async {
    logins++;
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

  test('initialization and popup requests cannot be duplicated', () async {
    final port = FakeAuth()..pendingInit = Completer<AuthIdentity?>();
    final session = AuthSession(port);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    final initializing = session.initialize();
    await session.initialize();
    await session.signIn();
    expect(port.initializations, 1);
    expect(port.logins, 0);
    port.pendingInit!.complete(null);
    await initializing;
    port.pendingLogin = Completer<AuthIdentity>();
    final signingIn = session.signIn();
    await session.signIn();
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
  test('popup cancellation, domain errors and blocked popup stay signed out',
      () async {
    final port = FakeAuth();
    final session = AuthSession(port);
    addTearDown(session.dispose);
    addTearDown(port.events.close);
    await session.initialize();
    for (final code in [
      'popup-closed-by-user',
      'popup-blocked',
      'unauthorized-domain',
      'operation-not-allowed'
    ]) {
      port.loginFailure = AuthFailure(code);
      await session.signIn();
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
    await session.signIn();
    expect(container.read(activeRepositoryProvider), isNull);
    expect(container.read(demoRepositoryProvider), isNot(same(previousDemo)));
    expect(container.read(transactionRepositoryProvider), isNot(same(old)));
  });
  testWidgets(
      'mobile login screen handles cancellation and success without claiming data persistence',
      (tester) async {
    final port = FakeAuth()
      ..loginFailure = const AuthFailure('popup-closed-by-user');
    addTearDown(port.events.close);
    final container = await mount(tester, width: 360, scale: 1.6, auth: port);
    container.read(routerProvider).go('/sign-in');
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
    await tester.ensureVisible(find.text('Google로 로그인'));
    await tester.tap(find.text('Google로 로그인'));
    await tester.pumpAndSettle();
    expect(find.text(authErrorMessage('popup-closed-by-user')), findsOneWidget);
    expect(find.text('로그인 완료'), findsNothing);
    port.loginFailure = null;
    await tester.tap(find.text('Google로 로그인'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 완료'), findsOneWidget);
    expect(find.text('first@example.com'), findsOneWidget);
    expect(find.textContaining('샘플 기록이 저장되거나'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
