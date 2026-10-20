import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../google_connection/google_connection.dart';
import '../google_connection/google_oauth.dart';
import '../transactions/transaction_repository.dart';
import 'sheets_ledger_repository.dart';

class LedgerSessionState {
  const LedgerSessionState({this.busy = false, this.error, this.createdId});
  final bool busy;
  final String? error;
  final String? createdId;
}

final ledgerSessionProvider =
    NotifierProvider<LedgerSession, LedgerSessionState>(LedgerSession.new);

class LedgerSession extends Notifier<LedgerSessionState> {
  int _generation = 0;
  @override
  LedgerSessionState build() {
    ref.listen<String?>(
        googleConnectionProvider.select((g) => g.profile?.subject),
        (previous, next) {
      if (previous != null && previous != next) {
        _generation++;
        ref.read(activeRepositoryProvider.notifier).state = null;
        state = const LedgerSessionState();
      }
    });
    ref.onDispose(() => _generation++);
    return const LedgerSessionState();
  }

  SheetsLedgerRepository _repository(String id) {
    final google = ref.read(googleConnectionProvider);
    final subject = google.profile?.subject;
    if (subject == null) {
      throw const ConnectionFailure('먼저 Google 로그인과 Sheets 동의를 완료해 주세요.');
    }
    return SheetsLedgerRepository(
        api: google.api,
        subject: subject,
        id: id,
        token: () {
          if (google.profile?.subject != subject) {
            throw const ConnectionFailure('계정이 변경됐어요. 원장을 다시 연결해 주세요.',
                reauthenticate: true);
          }
          return google.requireSheetsToken();
        });
  }

  Future<void> connect(String id) => _run(() async {
        final generation = _generation;
        final repository = _repository(id);
        await repository.refresh();
        if (generation == _generation) {
          ref.read(activeRepositoryProvider.notifier).state = repository;
        }
      });
  Future<void> create() => _run(() async {
        final generation = _generation;
        final google = ref.read(googleConnectionProvider),
            profile = ref.read(googleConnectionProvider).profile;
        if (profile == null) {
          throw const ConnectionFailure('먼저 Google 로그인해 주세요.');
        }
        String token() {
          if (google.profile?.subject != profile.subject) {
            throw const ConnectionFailure('계정이 변경됐어요. 다시 로그인해 주세요.');
          }
          return google.requireSheetsToken();
        }

        final id = await createLedgerTemplate(google.api, token,
            subject: profile.subject,
            email: profile.email,
            name: profile.name, onCreated: (id) {
          if (generation == _generation) {
            state = LedgerSessionState(busy: true, createdId: id);
          }
        });
        final repository = _repository(id);
        await repository.refresh();
        if (generation == _generation) {
          ref.read(activeRepositoryProvider.notifier).state = repository;
        }
      });
  Future<void> refresh() =>
      _run(() => ref.read(transactionsProvider.notifier).refresh());
  void useSample() {
    if (state.busy) return;
    _generation++;
    ref.read(activeRepositoryProvider.notifier).state = null;
    state = const LedgerSessionState();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (state.busy) return;
    final generation = _generation;
    state = LedgerSessionState(busy: true, createdId: state.createdId);
    String? error;
    try {
      await action();
    } on ConnectionFailure catch (e) {
      error = e.message;
      if (e.reauthenticate) {
        ref.read(googleConnectionProvider).invalidateSession();
      }
    } catch (_) {
      error =
          '원장 요청을 완료하지 못했어요. 네트워크와 시트 구조를 확인해 주세요. 생성 요청은 반영됐을 수 있으니 자동으로 다시 실행하지 마세요.';
    }
    if (_generation == generation) {
      state = LedgerSessionState(error: error, createdId: state.createdId);
    }
  }
}
