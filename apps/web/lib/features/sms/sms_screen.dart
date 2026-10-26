import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/bento_card.dart';
import '../export/download.dart';
import 'hana_parser.dart';
import 'sms_session.dart';
import 'sms_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmsScreen extends ConsumerStatefulWidget {
  const SmsScreen({super.key});
  @override
  ConsumerState<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends ConsumerState<SmsScreen> {
  final _name = TextEditingController(text: '내 휴대폰');
  final _senders = TextEditingController();
  final _cards = TextEditingController();
  String _platform = 'android';
  String? _export;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _senders.dispose();
    _cards.dispose();
    _export = null;
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) {
        setState(() => _error = failure is SmsFailure
            ? failure.message
            : '요청 결과를 확인하지 못했어요. 입력·인터넷 연결·기기 목록을 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(smsSessionProvider);
    final service = session.service;
    if (service == null) {
      return const Center(child: Text('먼저 로그인하고 공동 가계부를 연결해 주세요.'));
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('문자 자동 기록', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text(
          '연결된 휴대폰은 카드 문자를 이 가계부 수집함에 전송해요. 웹이 열려 있으면 등록한 하나카드 승인을 자동 기록해요. 웹을 닫았다면 다음에 열 때 반영돼요. 취소·미해석 문자는 직접 확인해 주세요.'),
      if (_busy || session.scanning) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      if (session.error != null) Text(session.error!),
      TextButton(
          onPressed: _busy ? null : session.retry,
          child: const Text('문자 자동 반영 다시 확인')),
      const SizedBox(height: 12),
      BentoCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('이 계정의 휴대폰 연결'),
        const Text(
            '본인이 받은 카드 문자만 연결하세요. 현재 하나카드 형식을 지원해요. 발신번호와 카드 식별자는 실제 결제 문자에서 확인해 주세요.'),
        TextField(
            controller: _name,
            enabled: !_busy,
            maxLength: 40,
            decoration: const InputDecoration(labelText: '기기 이름')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
            initialValue: _platform,
            items: const [
              DropdownMenuItem(value: 'android', child: Text('Android')),
              DropdownMenuItem(value: 'ios', child: Text('iPhone'))
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                      _platform = value!;
                      _export = null;
                    })),
        const SizedBox(height: 16),
        TextField(
            controller: _senders,
            enabled: !_busy,
            decoration: const InputDecoration(
                labelText: '카드 문자 발신번호', hintText: '실제 번호 · 여러 개는 쉼표로 구분')),
        const SizedBox(height: 16),
        TextField(
            controller: _cards,
            enabled: !_busy,
            decoration: const InputDecoration(
                labelText: '문자에 표시된 카드 식별자',
                hintText: '예: 하나1234 또는 하나12**34')),
        const SizedBox(height: 12),
        const Text(
            '카드 문자 본문이 같은 가계부 멤버에게 공유돼요. 확인을 마친 본문은 지우고 중복 방지 정보만 남겨요. 연결 파일은 문자 전송용 비밀 계정이므로 공유하지 말고 가져온 뒤 삭제하세요.'),
        FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      setState(() => _export = null);
                      final exported = await service.enroll(
                          ref.read(smsEnrollmentProvider),
                          name: _name.text,
                          senders: _senders.text,
                          cards: _cards.text,
                          platform: _platform);
                      if (mounted &&
                          identical(
                              service, ref.read(smsSessionProvider).service)) {
                        setState(() => _export = exported);
                      }
                    }),
            child: const Text('휴대폰 연결 파일 만들기')),
        if (_export != null) ...[
          TextButton(
              onPressed: () => downloadConnection(_export!),
              child: const Text('연결 파일 다운로드')),
          if (_platform == 'ios') ...[
            TextButton(
                onPressed: () => _run(
                    () => Clipboard.setData(ClipboardData(text: _export!))),
                child: const Text('iPhone 설정 JSON 복사')),
            const Text(
                'iPhone은 사용 가이드의 Firestore 단축어 설정을 따라 주세요. 고유 SMS 식별자가 없어 자동 합산하지 않고 수집함에서 승인 기록 추가를 눌러 확인해요.'),
          ] else
            const Text(
                'Android 문자 앱 1.1.0 이상에서 이 파일을 선택한 뒤 문자 권한을 허용하고 시작하세요. 기존 대기 문자는 먼저 처리해야 해요.'),
        ],
      ])),
      const SizedBox(height: 16),
      const SectionHeader('연결된 기기'),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.registrations,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('기기 목록을 불러오지 못했어요.');
            return Column(children: [
              for (final doc in snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                ListTile(
                  title: Text(doc.data()['name'] as String),
                  subtitle: Text(
                      doc.data()['enabled'] == true ? '문자 전송 허용' : '연결 차단됨'),
                  trailing: doc.data()['enabled'] == true &&
                          (doc.data()['ownerUid'] == service.user.uid ||
                              service.home.ownerId == service.user.uid)
                      ? TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() => service.disable(doc.id)),
                          child: const Text('차단'))
                      : null,
                ),
              const Text('최대 50개 기기를 표시해요. 더 많은 기기 관리는 운영자에게 요청해 주세요.')
            ]);
          }),
      const SizedBox(height: 16),
      SectionHeader('확인이 필요한 문자 ${session.pending.length}건'),
      if (session.pending.length == 50)
        const Text('앞의 50건부터 표시해요. 확인을 마치면 다음 문자가 나타나요.'),
      const Text(
          '취소 문자는 원거래를 확인한 뒤 해당 거래를 직접 수정·삭제하고 여기서는 확인 완료를 누르세요. 수동으로 이미 기록한 승인도 다시 추가하지 마세요.'),
      for (final doc in session.pending)
        Builder(builder: (context) {
          final value = doc.data();
          final parsed = parseHana(value['body'] as String,
              (value['receivedAt'] as Timestamp).toDate());
          return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: BentoCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(parsed == null
                        ? '문자 형식 확인 필요'
                        : parsed.cancelled
                            ? '취소 문자 · 원거래 확인 필요'
                            : '${parsed.merchant} · ${parsed.amount}원'),
                    Text('발신번호: ${value['sender']}'),
                    SelectableText(value['body'] as String),
                    if (parsed != null && !parsed.cancelled)
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                    final imported =
                                        await service.importApproval(doc.id,
                                            confirmed: true);
                                    if (!imported) {
                                      throw StateError('Not eligible');
                                    }
                                  }),
                          child: const Text('승인 기록 추가')),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => service.dismiss(doc.id)),
                        child: const Text('확인 완료 · 본문 지우기')),
                  ])));
        }),
    ]);
  }
}
