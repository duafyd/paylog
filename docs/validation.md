# 공유 Google Sheets 복귀 검증 (2026-10-28, 한국 시간)

현재 기준은 `feat/shared-google-sheets`, Google Sheets + GAS 및 Android 1.3.0/code7이다. Firestore/Cloudflare 실험은 실행 경로에서 제외했고 이전 작업은 별도 archive 브랜치에 보존했다. 기존 운영 Firestore/Sheets 데이터나 Cloudflare 자원은 수정/삭제하지 않았다.

- Flutter 분석: No issues found. 단위/위젯 67개 통과. iPhone 연결 파일의 플랫폼/발신번호와 원장에는 비밀값 해시만 저장되는 계약 포함.
- Flutter 웹: 모의 OAuth 설정과 운영 공개 OAuth ID 각각 릴리스 빌드 성공.
- Chromium: 샘플 CRUD/통계/세션 초기화, GIS 분리 동의/RAW/토큰 미저장/철회, Sheets 생성/연결/멤버 매핑/저장 응답 단절 후 GET 확인/조회 전용/로그아웃 검사가 통과했다. 외부 Google 계정/API는 모의 응답이다.
- Node SMS/GAS: 13개 통과, 생성 Code.gs 일치 포함. 브라우저 세션 없이 GAS doPost가 Android와 iPhone의 정상 승인을 바로 원장에 저장하고, 정확한 재전송은 중복 처리하며 다른 기기/실행의 같은 지문은 검토하고 삭제 표시된 거래가 재생성되지 않음을 검증했다. Apps Script/Sheets 서비스는 VM의 모의 API로 검증했다.
- Android: JDK21/API36/Gradle8.13에서 debug/release 단위 테스트 각 8개, lint 및 두 APK 빌드 성공. 이 환경의 릴리스 APK는 unsigned 검사 산출물이며 정식 APK는 본인 Cloud Shell의 기존 키로 서명해야 한다.
- Python 배포/릴리스 검사 22개 통과. Bash 배포 스크립트 구문 검사 통과. iPhone 레시피와 웹 배포본 JSON 일치.
- 실제 Google OAuth/가족 공유 ACL, 사용자 GAS 배포/실행 할당량 및 iPhone/Galaxy 자동화·잠금·배터리 상황은 이 개발 환경에서 검증하지 않았다. 실제 배포/실기기 완료로 보고하지 않는다.

웹/APK 배포와 GAS 새 버전 갱신은 [현재 운영 절차](SHARED_SHEETS.md)를 따른다. 아래는 과거 검증 기록이다.

---

# 실제 Hosting 배포 확인 (2026-10-20, 한국 시간)

사용자가 본인 Google Cloud Shell에서 Firebase 인증 및 배포 명령의 성공을 보고했고, 이후 공개 배포 주소 `https://paylog-c5c2d.web.app`를 별도로 확인했다.

- `/`: HTTPS 검증을 유지한 요청에서 HTTP 200, paylog HTML 응답.
- `/manifest.json`: HTTP 200, PWA manifest 응답.
- `/main.dart.js`: HTTP 200, 사용자 제공 공개 OAuth 클라이언트 ID 포함 확인.
- 개발환경의 Chromium 직접 접속은 플랫폼 프록시 CA를 신뢰하지 않아 ERR_CERT_AUTHORITY_INVALID로 실패했다. Python의 시스템 신뢰 저장소를 통한 HTTPS 요청은 성공했으며, 인증서 검증을 끄지 않았다. 격리된 NSS 신뢰 저장소 시도도 해결되지 않아 추가 브라우저 검증을 중단했다. 공개 배포의 화면 렌더링 성공으로 보고하지 않는다.
- 사용자 Google OAuth 로그인·Sheets 생성/가족 공유 ACL·GAS 실제 수집은 아직 미검증이다. 실제 모바일 기기 테스트는 요청에 따라 제외한 상태다.

아래 이전 절의 “실제 배포 미실행”은 당시 기록이다. 현재 웹 Hosting 배포는 확인했으며 GAS 배포와 Google 실제 연동 검증은 별도다.

---

# 배포 진행 결과 (2026-10-20 UTC)

사용자의 실제 배포 요청에 따라 Firebase CLI 로그인 상태를 확인했다. 저장된 계정은 0개이고 현재 프로세스의 FIREBASE_PROJECT_ID, GOOGLE_WEB_CLIENT_ID, FIREBASE_TOKEN은 설정되지 않았다. GitHub 저장소 Actions 변수/비밀값 목록은 현재 연동 권한으로 HTTP 403 거부되어 설정값을 가져오지 못했다. 플랫폼 GOOGLE_APPLICATION_CREDENTIALS는 사용자 계정 대신 사용하지 않았다.

배포 스크립트 `scripts/deploy-hosting.py` 및 사전 확인 테스트 **5개 통과**. `--deploy` 실행은 공개 설정 두 개 누락을 확인한 단계에서 종료 코드 1로 중단됐다. Hosting API 배포 요청·새 프로젝트 생성·외부 데이터 변경은 수행되지 않았다. 실제 배포 성공으로 간주하지 않는다. 필요한 설정과 안전한 인증 입력 방법은 [배포 안내](deployment.md)에 기록했다.

---

# 최신 검증 결과 (2026-10-20 UTC)

`feat/complete-budget-workflows`의 현재 구현 기준이다. 아래 이전 단계 기록은 당시 결과이며 현재 기능 목록은 이 절과 README를 우선한다.

| 검사 | 결과 |
|---|---|
| Flutter 포맷·정적 분석 | 통과, No issues found |
| Flutter 단위·위젯 | 60개 통과 |
| 기본/모의 OAuth ID 웹 릴리스 빌드 | 성공 |
| Chromium 샘플 브라우저 | 수입·지출 등록/수정/삭제, 통계, 세션 초기화 통과 |
| Chromium Google 연결 모의 검사 | 분리 동의·RAW·연결 해제·토큰 미저장 통과 |
| Chromium Sheets 원장 모의 검사 | 원장 생성/연결·UUID·응답 단절/GET 재확인·Viewer UI·로그아웃 통과 |
| SMS/GAS Node 테스트 | 12개 통과, 생성물 일치 포함 |
| Android JVM 테스트 | 1개 통과, endpoint/redirect allowlist의 여러 허용·거부 사례 |
| Android debug APK / Lint | 빌드 성공, Lint 통과 |
| Firebase Hosting 에뮬레이터 | SPA rewrite·보안/캐시 헤더·manifest 통과 |
| 실제 Google OAuth/CORS/공유 ACL | 미실행: 웹 클라이언트 ID·사용자 계정 설정 없음 |
| 실제 GAS 배포/HTTP 리다이렉트/Hosting 배포 | 미실행: 사용자 GAS 배포·Firebase 프로젝트/계정 설정 없음 |
| Galaxy S25 / iPhone 16 Pro 실기기 | 사용자 요청에 따라 제외 |

추가 Flutter 테스트는 UUID 행 이동 후 수정, 행 해시 충돌, 감사·SMS 출처 보존, 소프트 삭제, 수정/삭제 응답 단절 후 GET만 재확인, 불명확한 미반영 쓰기 재전송 금지, Google 403, 마지막 소유자 보호, 가족 참여 계정 바인딩·재참여 차단, 사용자 정의/비활성 카테고리, 관리 RAW 쓰기·충돌·기기 해시 보존·검토 처리, CSV 수식 주입 방지와 UI 수정/삭제를 다룬다.

SMS 테스트는 상세형/일반형, 누적금액 제외, 연말 연도 추론/불가능 날짜, 토큰 철회, 발신자/카드 필터, 멤버 간 마스킹 충돌, 카드 소유자 귀속, 중복/동일 금액 별도 거래, 취소/검토, ID 없는 메시지, 길이 제한, 거래/취소 마커 저장 후 응답 유실 복구를 확인한다. Apps Script 어댑터는 모의 UrlFetchApp/Sheets로 검증했다. 실제 Google 실행을 뜻하지 않는다.

Android에는 Keystore 암호화 큐·WorkManager·수신기가 구현되어 있으나 실제 SMS/키 저장소/백그라운드 실행은 테스트하지 않았다. iOS는 설정 가이드와 JSON 구성도이며 Apple 서명된 `.shortcut` 파일은 제공하지 않는다. Linux에서 해당 서명 도구를 사용할 수 없다. 자동 SMS 수집의 완성 또는 플랫폼 호환성을 단정하지 않는다.

Sheets의 변경 전 행 해시 확인은 최선 노력이다. 읽기와 쓰기 사이 경쟁, 브라우저와 GAS의 공동 트랜잭션 부재, 세션 종료 후 불명확한 웹 쓰기 기억 소실은 남아 있다. 관리 쓰기가 불명확하면 시트를 확인하고 목록을 다시 읽어야 한다. 오프라인 금융 데이터 저장·자동 동기화는 제공하지 않는다.

재현 명령은 README, Android README, [SMS 설정](sms-setup.md), [배포 안내](deployment.md)에 있다.

---

# Phase 1 검증 보고서

검증일: 2026-10-20 (KST). 대상: `feat/phase-1-flutter-web`.

## 수행 결과

| 검사 | 결과 | 확인 내용 |
|---|---|---|
| SDK 설치 | 성공 | Flutter 3.47.7 stable, Dart 3.13.5, Linux x64 |
| 잠금 파일 설치 | 통과 | `flutter pub get --enforce-lockfile` |
| 포맷 | 통과 | `dart format --output=none --set-exit-if-changed lib test` |
| 정적 분석 | 통과 | `flutter analyze`: No issues found |
| 단위·위젯 테스트 | 13개 통과 | 집계/금액 검증/월 경계/화면/등록 시나리오 |
| 릴리스 빌드 | 통과 | `flutter build web --release --no-web-resources-cdn` |
| Chromium 화면 실행 | 통과 | 390×844, 393×852, 402×874, 1280×1000; JS 오류·실패 요청 없음 |
| 브라우저 기능 검증 | 통과 | 지출 등록·통계 반영·수입 등록·새로고침 초기화 |
| 실제 iOS Safari / Android Chrome / PWA 설치 | 미실행 | 두 기기의 실제 브라우저·홈 화면 검증 필요 |
| Google 인증 / Sheets / SMS | 미구현·미실행 | 요청에 따라 다음 단계로 분리 |

테스트에서 생략 또는 예상 실패 처리한 케이스는 없다. 브라우저 검증은 Chromium에서 viewport를 바꿔 수행한 것으로 **기기 에뮬레이션이나 iOS WebKit 검증이 아니다.** 테스트 파일: `apps/web/test/transactions_test.dart`, `apps/web/test/widget_test.dart`. 재실행: README 및 `scripts/check.sh`, `scripts/browser-smoke.cjs`.

## 테스트 내용

- 월별 데이터 필터와 수입/지출 합계, 다른 월 제외 및 신규 거래 반영.
- 0원/음수/상한 초과/중복 ID 거부, 원화 천 단위 표기와 연도 구분.
- 360/390/393/402/430/1024px에서 달력 및 각 탭의 기본 레이아웃, 360px의 1.6배 글자 크기.
- 날짜 선택과 거래 조회, 12월 → 다음 해 1월 이동, 거래 없는 월의 0원 요약.
- 빈 필드·0원 등록 거부, 수입/지출 각각 정상 저장 후 정확한 데이터·선택일·성공 메시지 확인.
- 릴리스 브라우저에서 지출 25,000원 추가 시 총지출 180,600 → 205,600원, 눈이 지출 81,200 → 106,200원.
- 수입 100,000원 추가 시 총수입 4,200,000 → 4,300,000원. 새로고침 후 초기 샘플로 복귀.
- 커스텀 Flutter bootstrap은 서비스워커를 등록하지 않으며 렌더러 리소스를 같은 서버에서 제공한다. 오프라인 동작은 약속하지 않는다.

## 화면 검수

스크린샷을 직접 확인하고 큰 글씨에서의 헤더 넘침, 입력 전 금액 표시, 데스크톱 카드 비율을 조정했다. 앱은 기본 Material 컨트롤을 공통 테마·벤토 카드와 조합한다. 조작 영역과 화면 읽기용 달력 금액 레이블을 제공하며 접근성 전체 적합성 인증을 의미하지 않는다.

| 화면 | 캡처 |
|---|---|
| iPhone 16 Pro 크기 달력 (Chromium) | [달력](screenshots/iphone-16-pro-calendar.png) |
| iPhone 16 Pro 크기 등록 (Chromium) | [등록](screenshots/iphone-16-pro-form.png) |
| Galaxy S25 크기 달력 (Chromium) | [달력](screenshots/galaxy-s25-calendar.png) |
| Galaxy S25 크기 등록 (Chromium) | [등록](screenshots/galaxy-s25-form.png) |
| 데스크톱 | [달력](screenshots/desktop-calendar.png), [등록](screenshots/desktop-form.png) |
| 실제 브라우저 저장 결과 | [지출 등록 후](screenshots/browser-saved-expense.png) |

## 남은 기기 검증

- [ ] Galaxy S25 실제 Chrome에서 키보드가 열린 상태의 금액·메모 입력과 날짜·시간 선택.
- [ ] iPhone 16 Pro 실제 Safari에서 입력 확대, 키보드 복귀, 노치/홈 인디케이터 Safe Area.
- [ ] HTTPS 배포 후 두 기기의 홈 화면 추가, standalone 실행과 세로/가로 회전.
- [ ] VoiceOver / TalkBack 탐색과 OS 큰 글씨·동작 줄이기 설정.
- [ ] 다음 단계의 GIS 팝업·세션, Sheets 공유 ACL, 오프라인·충돌·재시도.

새 거래는 메모리에만 저장된다. 거래 수정·삭제·인증·영구 저장·SMS 기능을 제공하는 운영용 가계부가 아니며, 실제 금융 데이터를 보관하는 용도로 사용하지 않는다.

## 후속: Google 연결 PoC (2026-10-20 KST)

브랜치 `feat/google-sheets-poc`에서 Google 로그인·Sheets 동의·기존 시트 읽기·전용 테스트 시트 생성/쓰기·재조회·연결 해제를 추가했다. **실제 Google 계정 검증은 실행하지 않았다.** 웹 OAuth 클라이언트 ID와 승인된 원본 설정이 아직 없다. 샘플 원장과 실제 시트의 자동 전환도 구현하지 않았다.

- 정적 분석: `No issues found`. 포맷·잠금 파일 설치 통과.
- 단위·위젯 테스트: **27개 통과**, 생략·예상 실패 없음. 기존 13개에 Google API/상태 테스트 13개와 미설정 안내 위젯 테스트 1개를 추가했다.
- 기본 릴리스 번들과 모의 클라이언트 ID를 지정한 PoC 번들 각각 웹 빌드 성공.
- `scripts/google-connection-smoke.cjs`: **모의 GIS/API** 브라우저 테스트 통과. JS interop 콜백, 분리된 권한 요청, userinfo 기반 프로필, RAW append 후 UUID·금액 재조회, 기존 시트 GET만 수행, 정상 연결 해제와 철회 실패 안내, 브라우저 저장소에 토큰 미저장을 확인했다.
- `scripts/browser-smoke.cjs`: 기존 가계부의 수입·지출 저장/통계/새로고침 초기화 회귀 검사 통과. Flutter의 화면 밖 항목은 접근성 트리에 없을 수 있어 실제 스크롤과 입력 프레임 반영을 기다리도록 보완했다.
- 신규 연결 화면도 360/390/393/402/430/1024px 및 360px 1.6배 글씨 위젯 렌더링 검사를 통과했다. 설정된 상태의 브라우저 검사는 Chromium 402×874에서 수행했다.
- [모의 연결 검증 화면](screenshots/google-probe-mock.png)을 직접 확인했다. 입력란의 접근성 노드를 주변 설명·버튼에서 분리해 스크롤 후 입력 영역 겹침을 수정했다.

Google SDK 및 API를 Playwright로 대체했으므로 이 결과는 실제 OAuth 성공, Google 서버 CORS, 공유 ACL, 실제 Viewer 쓰기 거부, Chrome/Safari PWA 호환성을 입증하지 않는다. 외부 계정으로 시트를 만들거나 사용자 데이터를 수정하지 않았다. 실제 진행 절차와 미검증 항목은 [Google 설정 가이드](setup-google.md)에 있다.

## 후속: Sheets 원장 연결 (2026-10-20 KST)

브랜치 `feat/sheets-ledger`에서 실제 원장용 어댑터와 화면 전환을 구현했다. 실제 Google 계정/API 접속은 계속 **미실행**이며, 클라우드 프로세스에도 `GOOGLE_WEB_CLIENT_ID`가 아직 없다. 아래 결과는 코드·모의 응답 검증이다.

| 검사 | 결과 |
|---|---|
| 포맷·정적 분석 | 통과 / No issues found |
| 단위·위젯 테스트 | **47개 통과**, 생략·예상 실패 없음 |
| 웹 빌드 | 기본 릴리스 및 모의 클라이언트 ID 번들 각각 성공 |
| 기존 샘플 브라우저 검사 | 수입/지출·통계·새로고침 초기화 통과 |
| 기존 GIS/PoC 모의 브라우저 검사 | 분리 권한·시트 검증·연결 해제 회귀 확인 |
| 원장 모의 브라우저 검사 | 템플릿 생성 → 달력 전환 → 등록 → 결과 불명 재확인 → 통계 → 재접속 → 조회 전용 → 로그아웃 확인 |
| 실제 OAuth/CORS/Google 공유 ACL/두 실기기 | 미실행 |

새 테스트는 Members UUID/동명이인 구분, 서울 날짜와 잘못된 날짜 거부, 취소·검토·삭제 제외, 정수 금액·중복 UUID·알 수 없는 카테고리·다른 가계부 데이터 거부, 이전 정상 스냅샷 유지, Google 403, 불명확한 쓰기의 GET-only 재확인, 샘플 격리, 로그아웃 캐시 제거, 조회 전용/중복 탭/동일 초안 UUID를 다룬다. 원장 테스트 18개와 등록 위젯 테스트 2개를 추가했다.

`scripts/sheets-ledger-smoke.cjs`는 모의 서버에서 25,000원 거래를 저장한 뒤 POST 응답을 503으로 만든다. 화면은 성공을 표시하지 않고 재확인을 요청한다. 같은 UUID의 GET 확인으로 복구한 뒤에도 **append POST는 1회**다. 새로고침 후 로그인·같은 시트 재연결로 25,000원 기록을 복구했고, Members viewer 변경 후 등록 비활성화 및 로그아웃 후 샘플 복귀를 확인했다. RAW 문자열 수식 방지와 실제 계정의 감사 UUID도 검사했다.

[Sheets 달력 화면](screenshots/sheets-calendar-mock.png)은 Chromium 402×874에서 모의 응답으로 캡처하고 직접 검수했다. 조회 전용 및 불명확한 저장 위젯은 390px에서 확인했다. 기존 360/390/393/402/430/1024px와 큰 글씨 렌더링 테스트는 기본·미설정 화면 기준이다. 실기기/Safari 적합성을 뜻하지 않는다.

상세 사용 방법, 19열 `paymentMethod` 확장, 18열 조회 전용, Members·기본 카테고리 제약, 세션 종료 시 불명확한 저장 상태 소실과 Sheets 트랜잭션 한계는 [원장 가이드](sheets-ledger.md)에 기록했다. 가족 가입 UI·사용자 정의 카테고리·수정/삭제는 후속이며 실제 계정 설정과 공유 ACL 검증이 먼저 필요하다.

## 후속: 정식 Android 릴리스 준비와 앱 내 사용 가이드

웹 설정 → **Android · iPhone 사용 가이드**(`/help`)에서 홈 화면 설치, Google/원장 연결, Android APK·SMS 설정, iPhone 단축어 수동 구성·검토함 처리, 권한 오류 해결을 안내한다. Android 보조 앱에도 **사용 방법 보기** 대화상자를 추가했다. iPhone용 서명된 `.shortcut` 파일은 여전히 제공하지 않는다.

- Flutter 포맷·정적 분석 통과. 단위·위젯 **63개 통과**. 가이드 진입·스크롤·설정 복귀를 393/402px 및 360px 1.6배 글씨로 검사했다.
- Android debug/release JVM 테스트·Lint·APK 빌드를 통과했다. 릴리스는 `app.paylog.sms`, 버전 `1.0.0`/코드 `2`, 새 debug는 `.debug` 패키지로 구분한다.
- 일회용 검증 키를 사용한 릴리스 서명·인증서 일치·패키지·버전·디버그 비활성화 확인을 통과했다. **검증 키와 그 APK는 배포하지 않는다.**
- Python 배포/릴리스 테스트 **13개 통과**. 키 일부 누락 시 교체 키 생성 거부, 비밀 파일 게시 제외, unsigned APK 거부, 전용 사이트 설정을 확인했다.
- 다운로드 전용 Hosting 구성의 로컬 에뮬레이터에서 다운로드 페이지, APK MIME/attachment, 공개 체크섬 일치, 없는 파일 404를 확인했다.

본인 Cloud Shell의 영구 서명키를 사용한 **실제 정식 APK 게시와 공개 다운로드 검증은 아직 실행 전**이다. `scripts/release-android.py`가 키를 본인 계정에 보관하고 전용 Hosting 사이트에 APK·공개 인증서 지문·체크섬만 게시한다. 첫 실행 시 본인이 새 서명키 암호를 정하고 암호화된 키 파일을 백업해야 한다. GitHub CI는 서명키 없이 unsigned 릴리스 APK를 검증하며 해당 산출물을 설치용으로 안내하지 않는다. 웹 가이드가 실제 사이트에 표시되려면 웹 Hosting도 다시 배포해야 한다.

사용자는 실제 Google/Sheets 연결이 동작한다고 보고했다. 개발 환경에서 실제 거래 변경·가족 ACL·GAS 운영 배포까지 독립적으로 확인한 것은 아니다. 실기기 테스트는 요청에 따라 제외했고 SMS 수신, 삼성 배터리 제한, iPhone 메시지 자동화·Safari PWA는 계속 미검증이다.

### Hosting 배포 실패 복구

사용자의 Cloud Shell에서 Android 빌드 성공 후 Hosting deploy 실패가 보고됐다. 이후 프로젝트 목록·웹/Android 사이트 목록 조회는 성공했다. 실제 deploy 실패 원인은 아직 확인되지 않았다. `release-android.py --resume`으로 기존 APK·키의 검증을 유지하며 빌드를 생략하고, Firebase deploy의 일반 오류를 본인 터미널에 표시하도록 변경했다. Python 테스트 **15개 통과**(기존 APK 누락/소스 변경 거부 및 CLI 오류 전달 검사 추가). 이 결과는 실제 Hosting 업로드 성공을 의미하지 않는다.

### Spark 요금제 실행 파일 제한 대응

실제 오류는 Firebase Hosting `populateFiles`의 HTTP 400: **Executable files are forbidden on the Spark billing plan**이었다. 로그인 실패가 아니었다. APK 게시를 GitHub Releases로 옮겼으며 Firebase에는 HTML·JSON·체크섬만 배포한다. APK 파일은 staging에서 제거하고 Hosting ignore에도 추가했다. 기존 APK 경로는 GitHub 공개 asset으로 리다이렉트한다. 공개된 동일 버전은 덮어쓰지 않으며 APK 해시·인증서가 다르면 중단한다. 배포 관련 테스트 **17개 통과**. 실제 소유자 APK 업로드에는 본인 Cloud Shell의 GitHub 인증이 필요하며 아직 완료되지 않았다.

### OAuth 브랜딩용 공개 문서

`apps/web/web/privacy.html`, `terms.html`, `legal.css`를 추가했다. 문서는 로그인·JavaScript 없이 읽을 수 있고, 계정/원장/SMS 처리, 공유·보관·삭제·철회, 외부 제공자, 문의처와 이용 조건을 설명한다. 실제 거래 삭제가 소프트 삭제임을 명시하며 Google API Limited Use 정책을 포함한다. 공개 문의에 민감정보를 게시하지 않도록 안내한다. 웹 설정과 초기 HTML에서 링크한다. Google OAuth 게시·검증 승인은 별도이며, 최신 문서의 운영 사이트 반영에는 본인 Cloud Shell의 웹 재배포가 필요하다.

이 변경의 로컬 검증: Flutter 포맷·정적 분석·테스트 63개·웹 릴리스 빌드 통과. 393px Chromium에서 JavaScript 비활성 상태로 두 문서의 표시·가로 넘침 없음·내부 링크를 검사하고 화면을 검수했다. Hosting 에뮬레이터에서 실제 HTML 응답(Flutter SPA fallback 아님), no-store 헤더와 CSS 응답을 확인했다. 실제 공개 URL은 웹 재배포 전에는 준비 완료로 간주하지 않는다.

운영자가 공개 문의 이메일 `duafyd@gmail.com`을 지정해 두 문서에 반영했다. 일반 오류용 GitHub 문의와 개인정보 이메일 문의를 구분하고, Hosting 에뮬레이터 검사에 mailto 링크 확인을 추가해 통과했다.

## 2026-10-21 · Bento Grid + Modern Minimal UI

공통 테마를 웜 화이트·차콜·세이지·라임 팔레트로 개편했다. 지출/수입/잔액은 크기·색을 달리한 Bento 카드로, 달력 선택일은 고대비 차콜로 표시한다. 헤더·입력 필드·버튼·공통 카드·통계 요약을 통일하고, 하단 내비게이션은 너비를 제한한 독립 카드로 구성했다. 설정은 연결/관리·사용 가이드·데이터/약관 그룹으로 다시 배치했으며 각 항목에 버튼 접근성 레이블을 제공한다. 가이드에 `shortcuts://`로 같은 창에서 단축어 앱을 여는 버튼을 추가했다. 자동화 설정 자체는 사용자가 진행하며 실제 iPhone 실행은 미검증이다.

검증: Flutter 포맷·정적 분석·기존 테스트 63개·릴리스 웹 빌드 통과. 기존 테스트의 360/390/393/402/430/1024px 및 360px 1.6배 글씨를 포함한다. Chromium 샘플 거래 등록/수정/삭제·통계·새로고침 회귀 검사 통과. 393×852 모바일과 1280×900 데스크톱에서 캡처하고 직접 확인했다. 실기기 검증은 포함하지 않는다.

화면: [달력](screenshots/modern/calendar.png), [통계](screenshots/modern/statistics.png), [등록](screenshots/modern/entry.png), [설정](screenshots/modern/settings.png), [데스크톱](screenshots/modern/desktop.png).

현재 개발 환경에서 Firebase 사용자 인증 사전 확인은 실패했다(로그인 계정 없음). 본인 Cloud Shell의 인증은 별도 환경에 있으므로 실제 웹 반영에는 `git pull --ff-only && bash scripts/deploy-cloud-shell.sh` 실행이 필요하다. APK 변경·재설치는 필요하지 않다.

추가 회귀 검증: 테스트 OAuth ID로 별도 빌드한 Chromium의 Google 연결·Sheets 원장 모의 API smoke 2종도 통과했다. 새 설정 카드의 접근성 버튼 이름을 유지해 로그인 연결·원장 재접속·조회 전용·GET-only 저장 확인 경로를 검증했다. 이 검사는 실제 Google 계정이나 운영 시트를 변경하지 않는다.

## 2026-10-21 · 중립 색상과 Android 재수신 보호

사용자 피드백에 따라 녹색 계열을 화이트·차콜·블루로 교체했다. 색상 토큰도 accent/accentSoft/highlight로 정리했다. Android는 SMS만 수집하며 NotificationListenerService나 알림 접근 권한이 없어 문자 알림/카드 앱 푸시를 별도로 수집하지 않는 것을 확인했다.

1.0.1(code 3)은 SMS 발신자·원본 파트 시각·본문에서 결정적인 메시지 ID를 만들고, 큐 UUID와 분리한다. 재수신 시 큐가 추가되더라도 동일 기기의 서버 메시지 키가 같아 거래를 중복 추가하지 않는다. 서로 다른 원본 시각·발신자·승인/취소 본문·멀티파트 경계는 별도로 식별한다. 네트워크 재시도와 새 수신 처리 시각에 영향받지 않는 중복 확인을 JVM/서버 테스트로 검사한다. 서로 다른 기기나 내용/원본 시각이 바뀐 재발송의 의미 기반 중복 제거까지 보장하지 않는다. 실제 SMS 기기 검증은 계속 제외한다.

최종 검증: Flutter 정적 분석·테스트 63개·릴리스 빌드, Python 17개, SMS 서버 12개, Android JVM 5개(debug/release 각각)·Lint·debug/release APK 빌드를 통과했다. JVM 검사는 재수신 ID 일치·다른 시각의 같은 금액 결제·발신자/승인/취소 구분·멀티파트 경계·원본 시각 누락 거부를 포함한다. 웹 캡처 5종을 새 색상으로 교체했다. 1.0.1 정식 APK 서명·공개 업로드는 소유자 Cloud Shell 실행 전이며, 기존 소유자 키를 그대로 사용해야 한다.

## 2026-10-21 · 가족용 출시 준비

가족용 웹앱 + APK 직접 배포로 범위를 확정했다. `scripts/release-family.sh`는 본인 Cloud Shell에서 GitHub 로그인 사전 확인, 웹 배포, Android 서명 배포, 공개 릴리스 검증을 순차 실행한다. 마지막 성공 표시는 모든 단계가 통과할 때만 출력한다. 일부 단계가 실패하면 이미 반영된 앞 단계가 있을 수 있다.

`verify-release.py`는 HTTP 200인 SPA fallback을 정책 문서로 오인하지 않으며 정책 본문/문의처, manifest, 선택적인 로컬 웹 파일 해시 비교, 공개 APK 버전·다운로드 주소·크기·SHA-256을 검사한다. APK 인증서와 소유자 키의 일치는 기존 업로드 전 검사에서 확인한다. 사용자 데이터·로그인 토큰은 이 조회에 사용하지 않는다.

검증: Python 테스트 22개 통과, 배포 셸 문법 검사 통과, 실제 로컬 릴리스 빌드를 HTTP로 제공하여 정책 문서와 파일 해시 일치 확인 통과. 2026-10-21 최초 공개 조회에서 정책 URL이 앱 HTML을 반환했으며 후속 조회에서는 정상 정책 문서가 확인됐다. APK 공개 메타데이터는 1.0.0/code2로 확인되어 목표 1.0.1과의 버전 불일치를 검사 도구가 올바르게 보고했다. 이는 배포 완료가 아니라 현재 운영 버전 차이를 발견한 결과다.

[가족용 운영 가이드](FAMILY_RELEASE.md)에 계정/공유, 문자 수집, 서명키/원장 백업과 복구를 기록했다. 실제 가족 ACL·SMS·iPhone 검증은 자동 배포 검사와 별개이며 실기기 테스트는 개발 범위에서 제외한다.

작업 중 공개 배포가 갱신됐다. 최종 재조회에서 웹·정책 문서 검사와 APK 1.0.1/code3·공개 GitHub URL·실제 파일 크기/SHA-256 검사가 모두 통과했다. 앞선 1.0.0 오류는 최초 조회 시점의 상태다.

운영 OAuth ID로 독립 재빌드한 결과 공개 main.dart.js·index·정책 HTML·manifest·CSS가 바이트/해시 일치했다. flutter_bootstrap.js는 생성된 buildConfig의 JSON 키 순서만 다르고 로더와 설정은 동등함을 확인했다. 같은 배포 빌드에 대한 검사는 정확한 바이트 비교를 유지한다. 공개 APK 1.0.1을 직접 내려받아 apksigner 서명 검증·기존 1.0.0 공개 인증서와 동일함·aapt2 패키지/code3/버전/디버그 비활성화도 확인했다. 다운로드 파일은 검사 후 임시 폴더와 함께 정리했다.

## Android 1.0.2 간편 연결 (2026-10-21)

- Android 기본 화면을 연결 파일 선택 → 문자 권한 허용으로 변경하고 수동 입력은 고급 메뉴로 이동했다. 기존 암호화 설정은 유지한다.
- 웹 관리 → 기기 → Android 간편 연결은 활성 소유자 권한을 재확인하고 가족의 활성 카드 발신번호를 사용한다. 기기 UUID와 256비트 키를 생성해 Sheets에는 해시만 기록하며, 등록 재조회가 확인된 경우만 파일을 제공한다. 응답 단절 시 쓰기를 재시도하거나 키를 내보내지 않는다.
- 파일에는 평문 자격 증명이 포함되므로 앱 가져오기 후 삭제한다. URL 링크나 클립보드로 키를 전달하지 않는다. 파일 검증은 서버 접속 성공을 의미하지 않는다. 가족별 GAS 최초 설정과 카드 등록은 여전히 소유자가 준비해야 한다.
- Flutter 정적 분석, 전체 테스트 66개, 웹 release 빌드 통과. Android debug/release JVM 테스트 각 8개, lint 및 release 빌드 통과. 배포 스크립트 Python 테스트 22개 통과.
- 이 환경의 release APK는 운영 서명이 없는 빌드 검증용이다. 운영 서명·Firebase/GitHub 릴리스 게시에는 소유자 Cloud Shell의 `bash scripts/release-family.sh`가 필요하다. 실제 문서 선택기·SMS 수신·GAS 연동은 실기기 검증 범위로 남아 있다.
