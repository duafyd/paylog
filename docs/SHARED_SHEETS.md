# 공유 Google Sheets 운영 기준 (2026-10-28)

웹 → Google OAuth → 공유 Sheets, 휴대폰 → 소유자 GAS → 같은 Sheets로 통일한다. Cloudflare 계정/토큰이나 Firestore를 사용하지 않는다. 기존 Firebase 프로젝트 paylog-c5c2d의 Spark Hosting과 Android 서명키를 유지한다. 사용자 수를 앱에서 제한하지 않으며 외부 서비스 할당량과 Google 공유 제한은 적용된다.

## 가족 연결

1. 소유자가 웹 설정 → Google 연결 검증 열기 → Google 로그인 → Sheets 권한 요청을 완료한다. 각자 본인의 Google 계정을 사용한다.
2. 새 가계부 템플릿 만들기로 시작하거나 기존 paylog 스키마 시트를 연결한다. 임의의 표를 자동 변환하거나 샘플 거래를 복사하지 않는다.
3. 연결된 화면의 **시트 열기 · 가족 공유** → Google Sheets 공유에서 가족 이메일을 편집자로 추가한다. 링크가 있는 모든 사용자 공개로 바꾸지 않는다.
4. 가족은 본인 Google 로그인과 Sheets 동의 후 같은 시트 주소로 연결하고 표시 이름을 입력해 **현재 Google 계정으로 가족 참여**한다. 별도 앱 회원가입·초대 코드는 없다.
5. 웹 수동 등록/상세 수정/삭제 표시/통계/CSV는 같은 원장을 사용한다. 다른 기기와 SMS의 변경은 **원장 새로고침**으로 읽는다. 브라우저 종료 후 데이터는 시트에 남지만 로그인·연결은 다시 필요할 수 있다.

Google Sheets API와 웹 OAuth 클라이언트는 기존 설정을 재사용한다. OAuth 테스트 상태라면 가족을 테스트 사용자로 등록해야 한다. Sheets 권한 동의는 테스트 정책상 보통 7일 후 만료될 수 있어 재동의가 필요하다. Sheets로 돌아오면 이 OAuth 제한도 다시 적용된다. 브랜딩 인증을 완료했다고 이 코드가 보장하지 않는다. [설정](setup-google.md).

## 문자 자동 기록

1. [SMS 운영 설정](sms-setup.md)에 따라 소유자의 Apps Script 프로젝트에 `services/sms/gas/Code.gs`와 `appsscript.json`을 반영한다.
2. Script Properties의 SPREADSHEET_ID는 위 가족 시트로 지정한다. `setupSmsTables` 실행으로 관리 탭을 준비한다. 기존 데이터는 지우지 않는다.
3. 관리 화면에서 기본 지출 Categories(식비·생활·기타), Cards의 마스킹 카드 식별자/실제 발신번호/가족을 등록한다. 현재 파서는 하나카드 두 형식을 지원하며 다른 카드사를 모두 지원한다고 가정하지 않는다.
4. GAS를 **실행 사용자=소유자, 기기의 무인 요청 허용** 웹앱으로 배포하고 `/exec` 주소를 얻는다. 코드 수정 시 배포 관리 → 수정 → 새 버전으로 갱신한다. Hosting 배포만으로 GAS 코드가 바뀌지 않는다.
5. 관리 → 기기 → Android 또는 iPhone 간편 연결 → 가족과 GAS 주소를 선택해 파일을 만든다. 원장에는 키의 해시만 저장하고 원본은 파일/기기에만 둔다. 파일을 채팅에 보내지 않는다.
6. Android 1.3.0은 연결 파일을 불러와 SMS 수신 권한을 허용한다. 새 SMS만 수집하고 앱 알림은 읽지 않으므로 문자/알림 이중 수집을 피한다. 대기열은 기기에 암호화한다. Android의 배터리·네트워크 제한에 따라 지연될 수 있다.
7. iPhone은 [동작 레시피](../ios/sms-shortcut-template.json)에 따라 단축어와 메시지 즉시 실행 자동화를 최초 한 번 구성한다. 실행 UUID/시각은 요청 재시도에서 유지한다. 레시피는 서명된 설치 파일이 아니다.
8. 정상 승인은 GAS가 시트까지 저장한다. 웹 실행이나 매번 확인은 필요하지 않다. 원본 ID 재전송은 DUPLICATE, 다른 ID의 같은 의미 승인은 POSSIBLE_DUPLICATE 검토다. 실제 별도 결제라면 검토 후보를 보고 수동 거래로 추가한다. 취소는 원 승인 하나가 명확할 때만 자동 반영한다.

## 이전 데이터와 업데이트

Firestore 가계부를 사용했다면 먼저 기존 웹의 CSV로 백업하고 건수/합계를 확인한다. 이 릴리스는 Firestore 데이터를 읽거나 삭제하거나 시트에 자동 병합하지 않는다. 기존 Firestore용 연결 파일/계정은 GAS용으로 사용할 수 없다. 새 기기 파일을 만들고 Android를 업데이트하고 iPhone 단축어도 교체한다. GAS v1 연결 파일은 Android에서 계속 지원한다.

새 Android 버전은 1.3.0 / code 7이다. 본인의 기존 정식 서명키로 업데이트한다. Google Play 프로텍트는 직접 배포하는 SMS 권한 APK를 차단할 수 있다. 이 변경이 그 정책을 해결하지 않으며, 차단되면 보안 기능을 끄는 대신 안내를 확인하고 수동 기록을 사용할 수 있다.

기존 Cloudflare 토큰은 이 구조에 필요하지 않다. 원한다면 Cloudflare에서 폐기할 수 있다. 기존 클라우드 자원/계정은 자동 삭제하지 않는다.

## 배포

본인 Cloud Shell에서:

```sh
(
  set -e
  cd "$HOME/paylog"
  git fetch origin
  git switch feat/shared-google-sheets
  git pull --ff-only
  unset FIREBASE_TOKEN
  bash scripts/release-family.sh
)
```

위 명령은 웹과 정식 APK를 배포한다. **GAS는 앞 절대로 별도 갱신해야 한다.** 서명키와 Firebase/GitHub 인증은 본인 Cloud Shell에 유지한다. 실제 계정 인증/배포를 이 개발 환경에서 대신 수행했다고 보고하지 않는다.
