# 현재 아키텍처

브라우저 Flutter/Riverpod는 사용자 Google OAuth 토큰을 메모리에 보관하고 Sheets API를 직접 호출한다. GAS는 별도 SMS 수집 전용이다. 계정 변경 시 원장 캐시를 화면에서 제거한다. 두 경로 모두 RAW 쓰기와 UUID 참조를 사용한다.

- 웹: 달력·통계·등록·상세·수정·소프트 삭제·CSV. 행 해시로 변경 전 충돌을 확인하고 불명확한 쓰기는 GET만 재확인한다. 최종 읽기/쓰기 경쟁은 남는다.
- 관리: Members 가족 참여, 소유자의 Members/Cards/Categories/Devices/Review 변경. Sheets 공유 ACL이 실제 접근 경계이며 앱 역할은 서버 보안 경계가 아니다.
- SMS: `services/sms/src`의 순수 파서/수집 코어와 `gas/adapter.js`를 합쳐 배포용 `Code.gs` 생성. 기기 토큰 해시, 카드 매핑, 중복 키, 취소 마커 복구와 최소 검토 후보를 저장한다. 기기 수집자와 지출 카드 소유자를 구분한다.
- Android: `apps/sms_android` Kotlin receiver → Keystore 암호화 큐 → WorkManager → 소유자의 GAS. 기기 토큰은 로컬 암호화 설정에만 보관하고 WorkManager에는 큐 ID만 전달한다.
- iOS: 최초 메시지 자동화/단축어를 직접 설정하고 실행마다 생성한 UUID·시각을 재시도에서 유지한다. GAS가 정상 승인을 직접 시트에 기록한다. 같은 의미의 새 ID 승인은 검토한다. 서명된 `.shortcut` 설치 파일은 미제공이다.
- 배포: Firebase Hosting SPA/보안·캐시 헤더. CI는 웹/서버/Android를 검증한다. 금융 데이터 오프라인 저장·자동 동기화는 제공하지 않는다.

실제 Google 계정/공유 ACL/GAS 배포 검증은 사용자 설정이 없어 미실행이다. 실기기 검증은 이번 요청에서 제외했다. 최신 결과는 [검증 보고서](validation.md)를 따른다. 이하 절은 이전 단계 설계 기록이다.

---

# Phase 1 아키텍처와 개발 경계

## 이번 작업의 범위

Flutter Web + Riverpod + go_router의 모바일 우선 가계부를 샘플 데이터로 구현한다. 첨부 명세의 Phase 0/전체 MVP 지시 대신 이번 사용자 요청의 10개 항목을 적용한다. Google 로그인, Sheets, SMS는 다음 단계다. 가짜 로그인·성공하는 것처럼 보이는 동기화 버튼을 만들지 않는다.

- 앱 셸: `/` 달력, `/statistics` 통계, `/add` 수동 등록, `/settings` 상태/안내.
- 도메인: 양의 정수 KRW, 수입/지출 enum, 거래 날짜·시간, 멤버, 카테고리, 결제수단, 메모. UUID 식별자.
- 데이터: `TransactionRepository` 인터페이스와 세션 전용 `InMemoryTransactionRepository`. 읽기 전용 목록을 반환하고 중복 ID/잘못된 금액을 거부한다.
- 상태: `NotifierProvider`에서 거래 추가 후 새 목록을 발행한다. 월별 거래는 파생 Provider, 표시 월과 선택일은 별도 Provider. `clockProvider`로 테스트 시간을 고정한다.
- 프레젠테이션: 기능별 파일 분리. `BentoCard`, `SummaryCard`, `CalendarCard`/`DayCell`, `TransactionTile`, `CategoryTile`을 재사용한다.
- 디자인: 명세의 오프화이트·화이트·틸·큰 모서리를 적용하고, 텍스트 대비를 위해 보조색과 지출색을 조금 진하게 조정했다. 공통 ThemeData, Space, AppColors, 숫자 tabular 스타일을 사용한다. 모션 줄이기 설정을 존중한다.

## 보안 및 데이터 경계

샘플 사용자 이름은 권한 모델이 아니다. 이 앱은 실제 데이터를 저장하거나 공유하지 않는다. API 비밀키나 OAuth 설정이 필요 없다. 수입/지출 수정·삭제, 로컬 영구 저장, 재접속 복원도 이번 단계에 포함하지 않는다.

## 후속 개발 순서

1. **모바일 PoC**: 두 실기기에서 Safari/Chrome/홈 화면 PWA의 입력, 키보드, Safe Area, GIS OAuth 팝업·세션 검증. 실패 시 Safari 사용 등 명세 대안을 적용.
2. **Google 연결**: GIS 웹 사용자 인증과 Sheets OAuth 동의를 분리. 토큰은 메모리에만 보관하고 Sheets REST API로 직접 접근. 웹앱에서 GAS 범용 API를 호출하지 않는다.
3. **Sheets Repository**: UUID·Asia/Seoul 시각·감사 필드·행 버전/충돌 안내. Google 공유 ACL이 실제 접근 경계이며 Members 역할은 보안 권한이 아니다. 다른 가족 시트 접근 거부 및 Viewer 쓰기 거부 검증.
4. **거래 완성**: 상세/수정/소프트 삭제, 로딩·실패·재시도 UI, 데이터 보존과 네트워크 단절 처리.
5. **SMS**: 별도 GAS 수집 엔드포인트·기기별 토큰 해시·카드 allowlist·중복/취소 파서, Android 보조 앱과 iOS 단축어 실기기 PoC. 원문/토큰 로깅 금지. 웹 PWA는 SMS 권한을 요청하지 않는다.
6. **배포 품질**: Firebase Hosting HTTPS, 캐시/업데이트 정책, 오프라인 전략, 접근성·보안·무료 할당량 검증.


## Google 연결 PoC 추가

`features/google_connection/`에 GIS JS interop 포트, 세션 컨트롤러, 고정 Google API transport와 SheetsProbe를 분리했다. 설정 화면에서 `/google-connection`으로 이동한다. identity scope와 Sheets scope를 분리하고 userinfo의 subject를 비교하며 토큰은 메모리에만 보관한다. 프로필·오류·로딩·결과를 Riverpod ChangeNotifierProvider로 제공한다.

실제 가계부 Repository는 여전히 InMemory다. 기존 시트는 읽기·스키마 검사만 하고 쓰기는 새 테스트 시트에 명시적 동의 후 진행한다. 이 PoC의 테스트 행은 Members UUID 대신 Google subject를 임시 사용하므로 운영 원장으로 자동 전환하지 않는다. [설정 가이드](setup-google.md)의 실제 계정/실기기 체크리스트를 완료한 후 원장 어댑터를 구현한다.


## Sheets 원장 어댑터 추가

`features/ledger`에 캐시를 가진 비동기 `SheetsLedgerRepository`, 원장 세션과 연결/상태 UI를 추가했다. 기존 Repository 계약은 캐시 읽기 + 비동기 추가·새로고침으로 확장했다. 샘플 저장소와 활성 Sheets 저장소는 분리하며, 검증이 끝난 스냅샷만 교체한다. 계정 변경·로그아웃 시 표시 원장을 비우고 이전 비동기 응답이 다른 원장 화면을 덮지 않도록 세대를 확인한다.

Members UUID와 계정 subject를 매핑하고 표시 이름은 레이블로만 사용한다. 실제 공유 권한은 Google에 남긴다. 수동 등록은 입력 UUID를 유지하고 RAW append 뒤 재조회가 확인된 경우에만 성공한다. 응답 불명 상태에서는 같은 UUID의 GET 재확인만 허용하며 자동 재전송하지 않는다. Members 가입 UI·Categories UUID·수정/삭제·엄격한 동시성 보장은 후속이다. 상세 계약은 [Sheets 원장 가이드](sheets-ledger.md)에 기록한다.
