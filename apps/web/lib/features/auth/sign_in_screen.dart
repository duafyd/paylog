import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/platform/open_public_page.dart';
import '../../core/widgets/bento_card.dart';
import 'auth_port.dart';
import 'auth_session.dart';
import 'username.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _scroll = ScrollController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _formKey = GlobalKey<FormState>();
  bool _creating = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(firebaseSessionProvider).initialize();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _username.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(firebaseSessionProvider);
    if (session.busy || !session.ready || !_formKey.currentState!.validate()) {
      return;
    }
    if (_creating) {
      await session.register(_username.text, _password.text);
    } else {
      await session.signIn(_username.text, _password.text);
    }
    if (!mounted) return;
    if (session.user != null) {
      _password.clear();
      _confirmation.clear();
      FocusScope.of(context).unfocus();
      TextInput.finishAutofillContext();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  void _switchMode() {
    _password.clear();
    _confirmation.clear();
    ref.read(firebaseSessionProvider).clearError();
    setState(() {
      _creating = !_creating;
      _showPassword = false;
      _formKey = GlobalKey<FormState>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(firebaseSessionProvider);
    final user = session.user;
    return ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(20),
        children: [
          Text('우리 둘의 가계부 시작하기',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text('Google 계정 없이 아이디와 비밀번호로 시작해요.'),
          const SizedBox(height: 20),
          BentoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (user == null) ...[
                Text(_creating ? '간편 회원가입' : '아이디로 로그인',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                AutofillGroup(
                    child: Form(
                        key: _formKey,
                        child: Column(children: [
                          TextFormField(
                            controller: _username,
                            enabled: !session.busy,
                            autofillHints: const [AutofillHints.username],
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: '아이디',
                                helperText: '영문으로 시작하는 영문·숫자·밑줄 4~20자',
                                helperMaxLines: 2),
                            validator: (value) {
                              try {
                                normalizeUsername(value ?? '');
                                return null;
                              } on AuthFailure {
                                return authErrorMessage('invalid-username');
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            enabled: !session.busy,
                            obscureText: !_showPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: [
                              _creating
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password
                            ],
                            textInputAction: _creating
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_creating) _submit();
                            },
                            decoration: InputDecoration(
                                labelText: '비밀번호',
                                helperText: _creating
                                    ? '8~128자 · 다른 서비스와 다른 비밀번호를 사용하세요.'
                                    : null,
                                helperMaxLines: 2,
                                suffixIcon: IconButton(
                                    tooltip:
                                        _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                                    onPressed: session.busy
                                        ? null
                                        : () => setState(() =>
                                            _showPassword = !_showPassword),
                                    icon: Icon(_showPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility))),
                            validator: (value) {
                              try {
                                validatePassword(value ?? '',
                                    creating: _creating);
                                return null;
                              } on AuthFailure catch (error) {
                                return authErrorMessage(error.code);
                              }
                            },
                          ),
                          if (_creating) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmation,
                              enabled: !session.busy,
                              obscureText: !_showPassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration:
                                  const InputDecoration(labelText: '비밀번호 확인'),
                              validator: (value) => value == _password.text
                                  ? null
                                  : '비밀번호가 일치하지 않아요.',
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed:
                                session.ready && !session.busy ? _submit : null,
                            icon: Icon(_creating
                                ? Icons.person_add_outlined
                                : Icons.login),
                            label: Text(_creating ? '가입하고 시작하기' : '로그인'),
                          ),
                          TextButton(
                              onPressed: session.busy ? null : _switchMode,
                              child: Text(_creating
                                  ? '이미 계정이 있어요 · 로그인'
                                  : '처음이라면 회원가입')),
                        ]))),
                if (_creating)
                  const Text(
                      '이메일을 받지 않기 때문에 비밀번호 재설정 메일을 보낼 수 없어요. 아이디와 비밀번호를 안전하게 보관해 주세요.'),
              ] else ...[
                const Text('로그인 완료',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 12),
                Text('${user.username}님'),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: session.busy ? null : session.signOut,
                    child: const Text('로그아웃')),
              ],
              if (session.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(semanticsLabel: '계정 요청 처리 중'),
              ],
              if (session.error != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(session.error!)),
              ],
              if (!session.ready && !session.busy)
                TextButton(
                    onPressed: session.initialize,
                    child: const Text('로그인 다시 준비하기')),
            ]),
          ),
          const SizedBox(height: 16),
          const BentoCard(
              child: Text(
                  '현재는 회원가입·로그인 연결 단계예요. 가계부 만들기와 초대 코드로 함께 쓰는 기능은 다음 단계에서 연결합니다. 로그인만으로 샘플 기록이 저장되거나 기존 시트가 자동 이전되지는 않아요.')),
          const SizedBox(height: 16),
          const Text(
              '이 탭에서는 새로고침 후에도 로그인을 유지해요. 공용 기기에서는 사용 후 로그아웃해 주세요. Safari와 홈 화면 웹앱은 각각 로그인이 필요할 수 있어요.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            TextButton(
                onPressed: () => openPublicPage('/privacy.html'),
                child: const Text('개인정보처리방침')),
            TextButton(
                onPressed: () => openPublicPage('/terms.html'),
                child: const Text('서비스 이용약관')),
          ]),
        ]);
  }
}
