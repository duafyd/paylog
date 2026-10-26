import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_session.dart';
import '../household/household_session.dart';
import 'sms_service.dart';

final smsEnrollmentProvider = Provider<SmsEnrollment>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return SmsEnrollment(client);
});
final smsSessionProvider = ChangeNotifierProvider<SmsSession>((ref) {
  final home = ref.watch(householdSessionProvider.select((s) => s.household));
  final user = ref.watch(firebaseSessionProvider.select((s) => s.user));
  return SmsSession(home == null || user == null
      ? null
      : SmsService(ref.read(firestoreDatabaseProvider), home, user));
});

class SmsSession extends ChangeNotifier {
  SmsSession(this.service) {
    if (service != null) {
      _subscription = service!.pending.listen((snapshot) {
        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }
        pending = snapshot.docs;
        _changed = true;
        _scan();
      }, onError: (Object _) {
        error = '문자 수집함을 불러오지 못했어요. 연결과 보안 규칙을 확인해 주세요.';
        _notify();
      });
    }
  }
  final SmsService? service;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> pending = [];
  String? error;
  bool scanning = false, _changed = false, _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> retry() async {
    _changed = true;
    await _scan();
  }

  Future<void> _scan() async {
    if (_disposed || scanning || service == null) return;
    scanning = true;
    error = null;
    _notify();
    try {
      while (_changed && !_disposed) {
        _changed = false;
        for (final item in List.of(pending)) {
          if (_disposed) break;
          await service!.importApproval(item.id);
        }
      }
    } catch (_) {
      if (!_disposed) error = '문자 자동 반영을 확인하지 못했어요. 수집함에서 다시 확인해 주세요.';
    } finally {
      scanning = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    pending = [];
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
