import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';

class UsageGuideScreen extends StatelessWidget {
  const UsageGuideScreen({super.key});
  static const androidDownload = 'https://paylog-c5c2d-android.web.app/';

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('휴대폰 사용 가이드', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Android와 iPhone에서 설치부터 가계부 기록까지'),
          const SizedBox(height: 20),
          const _GuideCard(
            title: '먼저 가계부 연결하기',
            body: '1. 설정 → Google 연결 검증 열기에서 Google 로그인과 Sheets 접근 동의를 진행해요.\n'
                '2. 기존 가계부 ID·URL로 연결하거나 새 가계부 템플릿을 만들어요. 가족은 해당 시트 공유 권한과 Members 등록이 필요해요.\n'
                '3. 상단이 “Sheets 원장”인지 확인해요. “샘플 가계부”에서 입력한 기록은 새로고침하면 사라져요.\n'
                '4. 등록 탭에서 수입·지출을 저장하고 달력·통계에서 확인해요. 인터넷 연결이 필요하고, 다시 접속할 때 로그인·원장 재연결이 필요할 수 있어요.',
          ),
          const _GuideCard(
            title: 'Android · 홈 화면에 설치',
            body: '1. Chrome에서 https://paylog-c5c2d.web.app 을 열어요.\n'
                '2. 오른쪽 위 더보기 메뉴 → 홈 화면에 추가 → 설치 또는 추가를 선택해요. 메뉴 이름은 Chrome 버전에 따라 달라요.\n'
                '3. 홈 화면의 paylog를 열어 가계부를 연결해요. 수동 기록에는 별도 APK가 필요하지 않아요.',
          ),
          BentoCard(
            color: AppColors.tealSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Android · 문자 자동 수집'),
                const SizedBox(height: 12),
                const Text(
                    '1. 아래 다운로드 페이지에서 정식 서명 APK를 받아 설치해요. 최초 릴리스 게시 전에는 페이지가 열리지 않을 수 있어요.\n'
                    '2. 설치를 요청한 Chrome의 “알 수 없는 앱 설치”를 허용하고 APK를 열어요. 설치가 끝나면 해당 허용을 다시 꺼도 돼요.\n'
                    '3. 가계부 소유자가 GAS 수집 주소, 활성 기기 UUID·토큰, 카드·실제 발신번호 매핑을 준비해야 해요.\n'
                    '4. 문자 수집 앱에 GAS /exec 주소·기기 UUID·원본 토큰·허용 발신번호를 입력하고 “문자 수집 사용”을 켠 뒤 설정을 저장해요. SMS 수신 권한도 허용해요.\n'
                    '5. 이후 도착하는 허용 발신자의 새 SMS부터 수집해요. 기존 문자와 다른 앱의 알림은 읽지 않아요. 웹 달력 또는 관리의 검토함에서 결과를 확인해요.'),
                const SizedBox(height: 12),
                const SelectableText(androidDownload),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                        const ClipboardData(text: androidDownload));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('다운로드 주소를 복사했어요. 브라우저에서 열어 주세요.')));
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('APK 다운로드 주소 복사'),
                ),
                const Text(
                    '전송이 밀리면 네트워크와 앱의 최근 상태를 확인하고 “대기 전송 재시도”를 눌러요. Galaxy 설정의 배터리·백그라운드 사용 제한도 확인해요. 즉시 전송은 보장되지 않아요. 대기 문자는 최대 100건, 7일을 넘긴 항목은 다음 작업 때 정리돼요.\n\n'
                    '이전 개발용 APK는 서명이 달라 삭제 후 설치가 필요할 수 있어요. 삭제하면 설정과 대기 문자가 사라지므로 먼저 확인해요.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _GuideCard(
            title: 'iPhone · 홈 화면에 설치',
            body: '1. Safari에서 https://paylog-c5c2d.web.app 을 열어요.\n'
                '2. 공유 버튼 → 홈 화면에 추가 → 추가를 선택해요. iOS 버전에 따라 “웹 앱으로 열기” 옵션이 있으면 켜 주세요.\n'
                '3. 홈 화면의 paylog에서 Google 로그인·Sheets 동의 후 가계부를 연결해요. Safari와 홈 화면 앱의 로그인 상태가 다를 수 있어요.\n'
                'iPhone에는 Android APK를 설치하지 않아요. 홈 화면 웹앱에서 수입·지출을 직접 등록할 수 있어요.',
          ),
          const _GuideCard(
            title: 'iPhone · 문자 전송 단축어',
            body:
                '웹앱은 iPhone 문자를 직접 읽을 수 없어요. 문자 전송은 Apple 단축어를 기기에서 직접 구성해야 해요. 바로 가져오는 서명된 .shortcut 파일은 아직 제공하지 않아요.\n\n'
                '1. 소유자가 GAS를 준비하고 iOS 기기를 등록한 뒤 기기 UUID·원본 토큰·실제 발신번호를 받아요.\n'
                '2. 단축어 앱에서 “paylog 문자 전송”을 만들고 텍스트를 입력으로 받도록 설정해요.\n'
                '3. 사전 동작에 아래 필드를 넣어요. body에는 단축어 입력, receivedAt에는 시간대가 포함된 ISO 8601 날짜를 사용해요.\n'
                'action: sms.ingest\ndeviceId: 등록한 기기 UUID\ningestToken: 기기 원본 토큰\nsender: 등록한 실제 발신번호\nbody: 문자 본문\nreceivedAt: 수신 시각 (예: 2026-10-20T12:00:00+09:00)\n\n'
                '4. “URL 콘텐츠 가져오기”에서 본인 GAS /exec HTTPS 주소, POST, JSON 본문으로 위 사전을 전송해요. 응답의 ok가 true이고 code가 CREATED·DUPLICATE·IGNORED_CARD·REVIEW_REQUIRED인지 확인해요.\n'
                '5. 자동화 → 메시지에서 실제 카드사 발신자로 조건을 좁히고 문자 본문을 단축어에 전달해요. “즉시 실행”과 본문 전달 가능 여부는 iOS 버전에 따라 기기에서 확인해야 해요. 발신자가 여럿이면 자동화를 나눠요.\n'
                '6. 자동 실행이 안 되면 문자 본문을 복사해 단축어 입력으로 전달하거나 웹 등록 탭에서 직접 기록해요.\n\n'
                '실제 고유 메시지 ID가 없으면 검토함으로 보내며 합계에 바로 더하지 않아요. 재전송할 때 최초 receivedAt을 유지하고 임의의 새 messageId를 만들지 마세요. 검토함 후보를 확인해 수동 거래를 저장한 뒤 해당 거래 UUID로 검토를 마무리해요. 단축어를 공유할 때 토큰은 반드시 제거해요.',
          ),
          const _GuideCard(
            title: '연결·수집이 안 될 때',
            body:
                '• Google “테스터만 접근 가능” 안내: 소유자가 Google Auth Platform의 테스트 사용자에 로그인 이메일을 추가해야 해요.\n'
                '• Sheets 권한 오류: 로그인 계정의 시트 공유 권한, Sheets API 활성화, Sheets 접근 동의를 확인해요.\n'
                '• 문자가 누락됨: 기기·멤버·카드 활성 상태와 실제 발신번호, 기기 토큰, GAS 배포 주소를 확인해요. 파싱이 어려운 문자는 검토함으로 갈 수 있어요.\n'
                '• 기기 분실·토큰 노출: 소유자가 관리 → 기기에서 해당 기기를 비활성화해요. 토큰과 문자 원문을 채팅·스크린샷·공개 저장소에 올리지 마세요.\n'
                'Android 실제 SMS 수신과 iPhone 단축어 자동 실행은 아직 실기기 검증 전이에요. 자동 수집 설정이 끝나기 전에도 수동 기록은 사용할 수 있어요.',
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('설정으로 돌아가기'),
          ),
        ],
      );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title),
              const SizedBox(height: 12),
              Text(body, style: const TextStyle(height: 1.6)),
            ],
          ),
        ),
      );
}
