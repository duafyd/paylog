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
