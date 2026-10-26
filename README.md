# paylog

> **개발 방향 확정:** 기존 Firebase 프로젝트를 유지하고, 부부 두 사람이 사용할 Firebase Auth + Firestore(Spark 무료 플랜) 구조로 전환합니다. [전환 결정](docs/FIREBASE_MIGRATION.md). 저장 기능은 아직 Sheets 기반이며, 새 Firebase 로그인 연결 단계는 [전환 문서](docs/FIREBASE_MIGRATION.md)를 참고하세요.

가족의 일상을 가볍게 기록하는 Flutter Web 가계부. 기본은 샘플 모드이며, Google 로그인·Sheets 동의 후 원장을 연결하면 달력·거래 등록/수정/삭제·통계가 해당 시트를 사용합니다. 소유자 관리 화면, SMS 수집 GAS, Android 보조 앱과 iOS 설정 가이드도 포함합니다. **실제 Google 계정/API·실기기 검증은 아직 수행하지 않았습니다.** 공개 웹 클라이언트 ID를 설정해야 실제 연결을 시험할 수 있습니다.

- [원본 개발 명세](docs/DEVELOPMENT_SPEC.md)
- [Google OAuth 설정](docs/setup-google.md) · [Sheets 원장 사용·스키마·재시도 안내](docs/sheets-ledger.md)
- 배포 사전 확인: `python3 scripts/deploy-hosting.py` · 실제 배포: `python3 scripts/deploy-hosting.py --deploy` ([필수 계정/설정](docs/deployment.md))
- [SMS/GAS 운영 설정](docs/sms-setup.md) · [Android 앱](apps/sms_android/README.md) · [iOS 단축어](ios/README.md) · [배포/CI](docs/deployment.md)
- [아키텍처](docs/architecture.md) · [검증 결과](docs/validation.md)

## 실행

Flutter **3.47.7 stable / Dart 3.13.5**에서 검증했습니다. Flutter SDK와 Chrome이 필요합니다. 이 SDK 버전을 권장하며 `pubspec.lock`을 함께 관리합니다.

```sh
export PATH="/path/to/flutter/bin:$PATH"
cd apps/web
flutter pub get
flutter run -d chrome
# 원격 개발 머신에서는 아래 서버에 브라우저를 연결합니다.
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

기본 진입점은 `apps/web/lib/main.dart`입니다. 샘플 모드에서 수입/지출을 등록하면 현재 세션에만 반영되고 **새로고침·탭 종료 시 초기화됩니다.** 샘플은 실행 당시 서울 기준 월로 생성합니다. Sheets 모드의 신규 기록은 시트에 저장되며, 새로고침 후에는 같은 계정으로 로그인하고 시트 ID를 다시 연결해야 합니다. 날짜·시간 표시는 서울 기준입니다. 실제 서비스·실기기 검증 전에는 테스트 데이터로 확인하세요.

## 검증 및 빌드

```sh
cd apps/web
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
# build/web를 정적 서버에서 실행 (Python 3)
python3 -m http.server 8080 --directory build/web
```

웹 전체 검증은 저장소 루트에서 `bash scripts/check.sh`로 실행할 수도 있습니다. 추가 서버/Android 검증:

```sh
node --test services/sms/test/*.test.js
node services/sms/build.mjs
# JDK 21 + SDK 36 + Gradle 8.13
bash scripts/check-android.sh
# 빌드된 웹의 Hosting 설정만 로컬 검증 (실제 배포 없음)
npx firebase-tools@14.22.0 emulators:exec --only hosting --project demo-paylog 'node scripts/hosting-smoke.cjs'
```

거래를 눌러 상세→수정/삭제를 사용할 수 있다. CSV 내보내기는 설정 화면에서 제공하며 스프레드시트 수식 주입 문자를 무력화한다. 삭제는 Sheets `deletedAt`을 기록하여 합계에서 제외한다. 설정→가계부 관리에서는 실제 연결된 원장의 활성 소유자만 멤버·카드·카테고리·기기·검토함을 관리한다. SMS 관리 탭은 소유자의 GAS 설정 함수로 먼저 준비한다. 샘플 모드에는 관리 데이터가 없다.

가족은 소유자가 Google Sheets 공유 메뉴에서 먼저 편집자로 초대한 뒤 원장을 연결하고 표시 이름으로 참여한다. 앱 역할 변경은 Google 공유 ACL을 변경하지 않는다. 비활성 계정 재참여는 차단하며 마지막 활성 소유자는 해제할 수 없다. 사용자 정의 카테고리는 UUID로 참조하고 비활성화해도 과거 거래에서 유지한다. 상세 운영 절차는 위 문서를 따른다.

`.github/workflows/verify.yml`은 웹·SMS·Android 검사와 산출물 보관을 구성한다. 실제 Hosting/GAS 배포는 계정·프로젝트 설정이 필요하다. 실제 기기 검증은 이번 작업에서 제외했다. Apple 서명 `.shortcut`은 이 Linux 환경에서 생성하지 못해 JSON 구성도와 수동 설정 가이드를 제공한다.

추가 브라우저 smoke test는 정적 서버를 실행한 상태에서 별도로 실행할 수 있습니다. Node.js와 Chromium이 필요하며, Playwright는 앱 의존성과 분리해 설치합니다.

```sh
# 저장소 루트, 다른 터미널에서 build/web 정적 서버가 8080 포트로 실행 중일 때
npm install --prefix /tmp/paylog-browser-tools --no-save playwright@1.62.1
NODE_PATH=/tmp/paylog-browser-tools/node_modules CHROMIUM_PATH=/usr/bin/chromium node scripts/browser-smoke.cjs
```

`PAYLOG_BASE_URL`로 서버 주소를 바꿀 수 있습니다. 이 검사는 수입·지출 입력, 합계·통계 반영, 새로고침 초기화, JS 오류와 서비스워커 미등록을 검증합니다. 캡처는 무시되는 `apps/web/build/browser-smoke`에 저장합니다.

테스트는 월별 집계, 입력 검증, 수입/지출 저장, 날짜 선택, 연도 경계, 빈 상태, 360/390/393/402/430/1024px 레이아웃을 확인합니다. 실제 수행 결과는 [검증 보고서](docs/validation.md)를 확인하세요.

## 모바일 / PWA

- 모바일 하단 내비게이션, SafeArea, 반응형 1~2열 카드, 스크린리더용 달력 레이블을 제공합니다.
- 웹 manifest와 일반·maskable 아이콘, iOS 홈 화면 메타데이터를 포함합니다. HTTPS에 배포한 후 Chrome 메뉴 또는 Safari 공유 메뉴에서 홈 화면 추가가 가능합니다.
- 이 단계는 **온라인 실행 기준**입니다. 오프라인 캐시·데이터 보존·동기화는 구현하지 않습니다. 브라우저의 설치 UI 제공 여부는 브라우저 정책에 따릅니다.
- Galaxy S25 Android Chrome, iPhone 16 Pro Safari / 홈 화면 PWA의 키보드·설치·Safe Area는 실기기 검증이 별도로 필요합니다. CSS 뷰포트 테스트만으로 실기기 호환성을 보장하지 않습니다.

## 구성

```text
apps/web/lib/
  app/                    # go_router, 앱 셸 및 하단 내비게이션
  core/theme/             # 컬러·간격·타이포그래피
  core/widgets/           # BentoCard, SectionHeader, EmptyState
  features/calendar/      # 월 선택, 달력, 월간 요약
  features/transactions/  # 모델, Repository, Riverpod, 등록 폼
  features/statistics/    # 가족·카테고리별 지출
  features/settings/      # 원장 상태와 PWA 안내
  features/google_connection/ # Google OAuth 및 연결 PoC
  features/ledger/        # Sheets Repository, 원장 세션·연결 UI
```

Noto Sans KR은 앱에 포함하며 SIL Open Font License는 `apps/web/assets/fonts/OFL.txt`에 있습니다. 샘플 모드에는 API 키·인증 토큰이 필요하지 않습니다. Google 연결 PoC에는 공개 웹 OAuth 클라이언트 ID를 빌드 설정으로 전달합니다. 앞으로도 OAuth 토큰이나 기기 수집 비밀키를 웹 번들·Git에 포함하지 않습니다.

## 앱 내 사용 가이드와 정식 APK

웹앱 **설정 → Android · iPhone 사용 가이드**에서 홈 화면 설치, Google/가계부 연결, Android 문자 수집 앱 설치·설정, iPhone 단축어 구성과 문제 해결 방법을 볼 수 있습니다. Android 보조 앱에도 **사용 방법 보기**가 있습니다.

Firebase와 GitHub CLI(`gh auth login --hostname github.com --git-protocol https --web`)에 로그인한 본인 Cloud Shell의 저장소 루트에서 아래 명령으로 최신 웹 가이드와 정식 서명 APK를 각각 배포합니다.

```sh
git pull --ff-only && bash scripts/deploy-cloud-shell.sh && python3 scripts/release-android.py
```

최초 APK 릴리스에는 본인이 정하는 서명키 전용 새 암호(12자 이상)가 필요합니다. 암호화된 키 파일과 암호를 안전하게 백업하고 채팅·Git에 올리지 마세요. 정식 APK 다운로드 사이트는 스크립트 성공 후 이용할 수 있습니다. [상세 배포 절차](docs/deployment.md), [검증 결과와 미검증 항목](docs/validation.md)을 확인하세요.

현재 웹 UI는 **Bento Grid + Modern Minimal** 콘셉트로, 화이트 배경·차콜 요약 카드·블루 포인트·독립형 하단 내비게이션을 사용합니다. [변경된 화면 캡처와 검증 결과](docs/validation.md)를 확인할 수 있습니다.

## 가족용 정식 배포

[가족용 배포·운영 가이드](docs/FAMILY_RELEASE.md)에 최신 공개 상태, 가족 계정 설정, 백업·복구 절차를 정리했습니다. 본인 Cloud Shell에서 최신 코드를 받은 뒤 `bash scripts/release-family.sh`를 실행하면 웹·APK 배포와 공개 정책 문서·빌드 해시·APK 버전/해시 검증을 순서대로 수행합니다. 조회만 하려면 `python3 scripts/verify-release.py`를 실행합니다.
