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
