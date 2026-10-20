# paylog

가족의 일상을 가볍게 기록하는 Flutter Web 가계부. **Phase 1은 샘플 데이터 모드**이며 달력의 실제 Google 인증·Sheets 저장·SMS 수집은 연결하지 않습니다. 별도 설정 화면에 **Google 로그인·Sheets 읽기/쓰기 연결 PoC**를 제공하며 [설정 가이드](docs/setup-google.md)를 따라 공개 웹 클라이언트 ID를 구성해야 합니다. 원본 요구사항은 [개발 명세](docs/DEVELOPMENT_SPEC.md), 이번 구현 범위와 후속 계획은 [아키텍처](docs/architecture.md)를 참고하세요. 첨부 명세의 전체 MVP와 이번 단계의 완료 범위는 다릅니다.

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

기본 진입점은 `apps/web/lib/main.dart`입니다. 화면에서 수입/지출을 등록하면 같은 세션의 달력, 합계, 통계에 반영됩니다. **새로고침·탭 종료 시 신규 기록은 사라집니다.** 실제 금융 정보를 입력하지 마세요. 샘플은 실행 당시 월을 기준으로 생성됩니다. 현재 시각과 수동 입력은 브라우저 현지 시각을 사용하며, Sheets 단계에서 Asia/Seoul 직렬화를 도입할 예정입니다.

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

전체 검증은 저장소 루트에서 `bash scripts/check.sh`로 실행할 수도 있습니다.

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
  features/settings/      # 샘플 상태와 PWA 안내
```

Noto Sans KR은 앱에 포함하며 SIL Open Font License는 `apps/web/assets/fonts/OFL.txt`에 있습니다. 샘플 모드에는 API 키·인증 토큰이 필요하지 않습니다. Google 연결 PoC에는 공개 웹 OAuth 클라이언트 ID를 빌드 설정으로 전달합니다. 앞으로도 OAuth 토큰이나 기기 수집 비밀키를 웹 번들·Git에 포함하지 않습니다.
