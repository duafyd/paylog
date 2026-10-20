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
