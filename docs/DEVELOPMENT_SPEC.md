# 가족 공유 가계부 웹앱 개발 명세서 (Codex 전달용)

- 문서 버전: 2.0 — 실현 가능성 재검토 반영
- 작성일: 2026-10-19
- 상태: 구현 계획 / MVP 기준
- 목표: **서버를 직접 운영하지 않고**, Android(Galaxy S25) 및 iOS(iPhone 16 Pro)에서 사용할 수 있는 가족 공유 가계부를 개발한다. 지출 SMS를 지정 카드에 한하여 자동 수집하고, Google Sheets에 저장하며, 달력형 웹앱에서 조회·추가·수정한다.

## 1. 확정 요구사항

1. 사용자 UI는 **Bento Grid + Soft Minimal(벤토 + 소프트 미니멀)** 디자인 시스템을 적용한 **Flutter Web PWA**. 앱스토어/플레이스토어 배포 없이 URL 및 홈 화면 추가로 이용한다.
2. 각 기기에서 **Google 계정 로그인 및 Sheets OAuth 권한 승인**, 표시 이름 설정이 가능하다. 가족 참여는 MVP에서 소유자가 시트를 Google 계정 이메일에 공유하는 방식으로 제공한다. 자동 초대 코드·완전 자동 가입은 후속 범위다.
3. 가계부 소유자가 **Google Sheets를 생성/선택**하고 가족 Google 계정에 시트 공유 권한을 부여한다. 각 가족 구성원은 본인 OAuth 토큰으로 Google Sheets API에 직접 접근한다.
4. 월간 달력, 날짜별 거래, 사용자별 지출, 카테고리별 통계, 수입/지출 수동 추가·편집·삭제를 지원한다.
5. 카드사/문자 발신자/카드 식별 문자열(예: `하나3*8*`)을 조합해 **허용된 카드만** 자동 등록한다.
6. **Android**는 별도 경량 네이티브 **SMS 수집 보조 앱**으로 문자 수신 → API 전송. 웹앱에 SMS 읽기 기능을 요구하지 않는다.
7. **iOS**는 Apple **단축어의 메시지 수신 개인용 자동화**로 문자 본문 → API 전송을 우선 시도한다. 실제 기기에서 자동 실행/본문 전달 가능 여부를 반드시 검증한다. iOS에서 다른 앱의 푸시 알림 직접 수집은 범위 밖이다.
8. 별도 상시 구동 서버/유료 API를 필수로 요구하지 않는다. Google Sheets API를 웹앱의 읽기/쓰기 계층으로 사용하고, Google Apps Script(GAS)는 **SMS 수집 전용 엔드포인트** 및 원장 정규화 처리에 사용한다. 무료 할당량 내 운영을 목표로 한다.
9. 수집된 SMS는 **거래 후보**로 파싱·검증 후 저장하며, 취소·중복·형식 오류를 처리한다.

## 2. 비목표 / 제약

- 카드사 API 직접 연동, 은행 계좌 스크래핑, OCR 기반 자동 인식, 실시간 결제 푸시 수집은 MVP에서 제외.
- Google Sheets는 관계형 DB가 아니다. 소규모 가족 사용량을 전제로 하며, 동시 편집·API 할당량·시트 크기 제한에 대비한다.
- GAS는 Google이 호스팅하는 서버리스 실행 환경이지 완전한 '서버 없는 클라이언트만의 앱'은 아니다.
- **Android SMS 권한은 Google Play 정책상 제한 대상**일 수 있다. MVP는 직접 설치(sideload)·내부 테스트를 전제로 하고, 실제 권한 동작/OS 백그라운드 제한을 실기기에서 확인한다. 배포 경로를 바꿀 경우 정책 재검토.
- iOS 단축어는 설치·자동화 구성에 사용자 조작이 필요하며, OS/단축어 변경에 따라 제약이 있을 수 있다. 100% 무인 실행을 검증 전 보장하지 않는다.

## 3. 플랫폼별 기능 검토 (Galaxy S25 / iPhone 16 Pro)

| 기능 | Galaxy S25 Chrome PWA | iPhone 16 Pro Safari PWA | 구현 판단 |
|---|---|---|---|
| 웹앱 홈 화면 추가/실행 | 가능 | 가능(Safari 공유 메뉴) | 가능 |
| Google 로그인/표시 이름 | 가능 | 가능, 팝업/홈 화면 PWA 세션 별도 테스트 | 조건부 가능 |
| Sheets 읽기·쓰기 | OAuth 권한 승인 후 가능 | OAuth 권한 승인 후 가능 | 가능, 실제 모바일 OAuth PoC 필수 |
| 달력·통계·수동 등록/편집 | 가능 | 가능 | 가능 |
| PWA의 SMS 직접 수신 | 불가 | 불가 | **금지** |
| SMS 자동 수집 | Kotlin 보조 앱, RECEIVE_SMS | 메시지 자동화 단축어, 사용자 설정 | 조건부 가능 |
| 수신 SMS에서 특정 카드만 등록 | 서버 측 카드 필터 | 서버 측 카드 필터 | 가능(마스킹 충돌은 검토) |
| SMS 승인 취소·중복 제거 | 파서/원장 처리 | 파서/원장 처리 | 가능(승인번호 없는 거래는 모호할 수 있음) |
| 스토어 없이 배포 | PWA + 보조 앱 APK 직접 설치 | PWA + 사용자 단축어 설정 | 가능, iOS 자동화는 앱 설치가 아닌 설정 필요 |

**판정:** 웹 가계부는 구현 가능. SMS 자동화는 실기기 PoC가 완료되기 전까지 '완전 자동 보장'으로 표현하지 않는다. 특히 iOS의 문자 트리거가 실제 입력 본문을 전달하는지, `URL 내용 가져오기` POST가 자동 실행되는지, 응답 리다이렉트를 처리하는지 확인한다.

## 4. 최종 아키텍처 및 권한 모델 — v1.1의 문제 수정

```text
 Galaxy S25 Chrome PWA             iPhone 16 Pro Safari PWA
       |                                       |
       +---- Google Identity Services --------+
                        |
             Google Sheets API (HTTPS/CORS)
                        |
        소유자가 공유한 Google Spreadsheet
                        ^
                        |
             Google Apps Script (SMS 전용)
                 ^                 ^
                 |                 |
         Android Kotlin 앱      iOS 단축어
```

### 4.1 가장 중요한 변경: 웹앱에서 GAS API를 직접 호출하지 않음

- 이전 설계의 `Flutter Web → GAS doPost/doGet` 범용 API는 **브라우저 CORS/프리플라이트, GAS ContentService 리다이렉트, 사용자 토큰 검증**이 복잡해질 수 있다.
- **MVP에서는 Flutter Web → Google Sheets REST API를 직접 호출**한다. Google Identity Services(GIS) OAuth 액세스 토큰으로 `Authorization: Bearer ...`를 보내며 Google API가 지원하는 CORS를 활용한다.
- 로그인(사용자 식별)과 Sheets OAuth 권한 동의는 별개다. `spreadsheets` 접근 범위는 사용자가 이해할 수 있게 안내하고, 범위를 최소화한다. OAuth 앱 검증/테스트 사용자 제한 및 공개 전 검증 요구사항을 확인한다.
- Flutter Web에서는 GIS를 JS interop으로 연결하거나 현재 유지보수 중인 웹용 인증 패키지를 검증해 사용한다. **Android 네이티브용 google_sign_in 흐름을 웹에서 그대로 재사용한다고 가정하지 않는다.**
- 액세스 토큰은 메모리에서 관리하고 만료 시 사용자 상호작용으로 갱신한다. 브라우저 localStorage에 장기 토큰을 저장하지 않는다. iOS 홈 화면 PWA의 로그인 팝업/세션 유지도 검증한다.
- 소유자와 가족은 같은 스프레드시트에 Google 공유 권한을 통해 접근한다. `Members.role`은 UI 역할 표시이며 **Sheets API를 직접 사용하는 이상 앱 내부 owner/editor/viewer 역할만으로 데이터 변경을 막을 수 없다.** 진짜 읽기 전용은 Google Sheets 공유 권한 `Viewer`로 제한한다.
- 편집자 권한을 받은 가족은 웹앱 밖에서 시트를 직접 수정할 수 있다. 강한 행 단위 ACL, 임의 사용자 차단, 세밀한 감사 기능이 필요하면 Firestore/Cloud Run 등 별도 관리형 백엔드가 필요하다. **MVP에서 보장하지 않는다.**

### 4.2 Google Sheets 연결·가족 공유의 실제 MVP 동작

1. 소유자가 Google 로그인 및 Sheets 권한 승인.
2. 시트 템플릿을 본인 계정에 생성하거나 기존 스프레드시트 ID를 등록. 자동 생성은 Sheets API `spreadsheets.create` PoC 후 적용.
3. 소유자가 Google Sheets 공유 메뉴에서 가족 Google 이메일을 **편집자** 또는 **뷰어**로 초대(수동 단계).
4. 가족은 웹앱 로그인 → Sheets 권한 승인 → 공유받은 스프레드시트 ID/초대 링크를 등록.
5. 각 사용자의 표시 이름을 `Members` 시트에 저장. **임의 사용자 ID/이메일을 권한 증거로 사용하지 않는다.** 권한 경계는 Google의 실제 시트 공유 권한.
6. 여러 가족/다중 시트 자동 관리, 앱 자체 초대 코드로 Drive 공유 자동화는 추후 별도 OAuth Drive 권한/보안 설계 후 구현.

### 4.3 SMS 수집 GAS 엔드포인트 (웹앱과 분리)

- 소유자가 배포한 Apps Script 웹앱이 **소유자 권한으로만** 해당 시트에 SMS 거래를 기록한다. `doPost`는 외부 단축어/Android 앱에서 접근 가능한 URL이어야 한다.
- SMS 엔드포인트는 Google 로그인 쿠키에 의존하지 않고 **기기별 충분히 긴 난수 비밀 토큰**으로 인증한다. 토큰은 HTTPS POST 본문으로 전달, 서버에는 해시만 저장하고 폐기/교체를 지원한다. `doPost`에서 Google 사용자 이메일이 자동 식별된다고 가정하지 않는다.
- GAS 공개 URL은 누구나 호출을 시도할 수 있으므로 인증 실패/잘못된 카드/과도한 요청을 무시한다. GAS 자체에 강력한 IP 기반 rate limit/WAF가 없다는 한계를 명시한다. 높은 보안이 필요하면 관리형 API로 이전한다.
- 문자 원문은 승인 여부 판단 후 가능한 한 즉시 버리고 최소 거래 정보만 저장. 요청/응답에 토큰이나 카드 원문을 기록하지 않는다.
- SMS 처리에서 `LockService`로 동시 요청 직렬화, `messageId` 기반 idempotency 및 fingerprint 중복 확인. 직접 Sheets API를 쓰는 웹 편집과 GAS 쓰기 사이에는 **공통 트랜잭션이 없으므로** 변경 버전 확인·충돌 안내·재조회 구현.
- iOS 단축어/Android HTTP 클라이언트가 GAS ContentService 응답 리다이렉트를 정상 처리하는지 확인. 확인 전에는 성공/실패 응답 신뢰를 전제로 자동 삭제하지 않는다.

### 4.4 권장 기술 스택

| 계층 | 기술 | 설명 |
|---|---|---|
| 공통 UI | Flutter Web + Riverpod + go_router | Bento + Soft Minimal PWA |
| 호스팅 | Firebase Hosting 무료 한도 | HTTPS 정적 호스팅, **Firebase Auth/Functions 필수 아님** |
| 사용자 인증/권한 동의 | Google Identity Services (웹 OAuth) | Google Sheets API 호출용 사용자 토큰 |
| 웹 데이터 접근 | Google Sheets REST API | 브라우저에서 직접 접근, Google 시트 공유 ACL 적용 |
| 저장 | Google Sheets | 가족 공동 원장 |
| SMS 수집/파싱 | Google Apps Script | 공개 엔드포인트 + 기기 토큰 + 소유자 시트 쓰기 |
| Android SMS | Kotlin + RECEIVE_SMS + WorkManager | 직접 설치 APK, 네트워크 재시도 |
| iOS SMS | Apple Shortcuts 메시지 자동화 | URL 내용 가져오기 POST, 실기기 PoC |

### 4.5 비용·공개 배포 주의

- 가족 2명·적은 거래량이면 무료 한도 내 운영 가능성이 높지만 **항상 0원/무제한은 보장하지 않는다.** Google API/GAS/Hosting 할당량 확인.
- Google Sheets OAuth 범위는 민감 범위로 분류되거나 공개 배포 시 검증 절차가 필요할 수 있다. 테스트 사용자 모드, OAuth 동의 화면, 공개 서비스 전 검증을 확인한다.
- Google Sheets는 완전한 DB가 아니므로 사용자 수/거래량 증가 시 별도 데이터 저장소 전환 고려.

## 5. 주요 사용자 시나리오

### 5.1 첫 사용
1. PWA 열기 → Google 로그인.
2. 표시 이름 지정(예: 눈이, 딘이).
3. 소유자는 시트 생성/선택 및 가족 계정에 Google Sheets 공유 권한 부여. 가족은 공유된 시트 ID로 참여.
4. 각 사용자에게 Sheets OAuth 권한을 요청하고 읽기/쓰기 접근을 확인.
5. 카드 설정에서 카드사, 발신번호, 마스킹 카드 식별값, 소유 사용자, 자동 등록 여부 설정.
6. 기기별 SMS 자동화 설정 안내(Android 보조 앱 / iOS 단축어).

### 5.2 SMS 자동 등록
1. 기기에서 카드사 SMS 수신.
2. Android 앱 또는 iOS 단축어가 원문과 수신 시각, 수집 기기 ID를 GAS SMS 전용 엔드포인트에 제출.
3. GAS가 수집 기기 인증, 발신번호, 카드사, 카드 식별값을 검사.
4. 허용 카드인 경우만 파싱 → 중복 검사 → 거래 생성. 비대상 문자는 저장하지 않는다.
5. 파싱 실패/애매한 카드는 `review_required` 상태로 보류하며, 민감한 원문은 원칙적으로 영구 저장하지 않는다.
6. 웹앱 달력과 목록에서 확인·수정.

### 5.3 수동 등록
- 거래일시, 입금/지출, 금액, 사용자, 카테고리, 가맹점/메모, 결제수단 입력.
- 추가·수정·삭제 시 `updatedAt`, `updatedBy` 기록; 삭제는 소프트 삭제 권장.

## 6. 화면/UX 요구사항 — Bento Grid + Soft Minimal

### 6.1 디자인 방향 (필수)

**전체 UI 콘셉트는 `Bento Grid + Soft Minimal(벤토 + 소프트 미니멀)`로 고정한다.** 단순한 Material 기본 위젯 나열이나 과도한 글래스모피즘/뉴모피즘/그라디언트 디자인으로 대체하지 않는다.

- **Bento Grid:** 정보를 목적별 카드로 묶고, 중요도에 따라 카드 크기를 다르게 구성한다. 월 지출·수입·잔액·사용자별 지출·카테고리 통계 등을 직관적인 대시보드로 배치한다.
- **Soft Minimal:** 넓은 여백, 은은한 배경색, 부드러운 모서리, 약한 그림자, 간결한 아이콘, 명확한 타이포그래피. 정보 밀도는 낮추되 가계부 숫자 가독성은 최우선.
- **모바일 우선:** Galaxy S25와 iPhone 16 Pro의 세로 화면을 기준으로 설계한다. 작은 화면은 1~2열 벤토 카드, 넓은 화면은 2~4열로 반응형 배치한다.
- **실용성:** 금융 데이터의 정확성과 조작 편의성이 시각적 장식보다 우선한다. 달력과 거래 목록은 읽기 쉬워야 하며 카드 안에 과도하게 압축하지 않는다.
- **일관성:** 로그인/온보딩, 달력, 거래 등록, 통계, 카드 설정, 가족 관리까지 동일한 토큰과 컴포넌트를 사용한다.

### 6.2 디자인 토큰 (초기 제안, 중앙 관리)

| 항목 | 기준 |
|---|---|
| 배경 | 따뜻한 오프화이트 `#F7F8FA` |
| 카드 배경 | 화이트 `#FFFFFF` |
| 기본 텍스트 | 딥 슬레이트 `#202733` |
| 보조 텍스트 | `#737D8C` |
| 포인트 컬러 | 차분한 틸 `#258B86` |
| 포인트 약한 배경 | `#E7F4F1` |
| 지출 | `#D65D62` (색상 외 `-`/레이블도 함께 사용) |
| 수입 | `#258B86` (색상 외 `+`/레이블도 함께 사용) |
| 카드 모서리 | 20~24dp |
| 버튼/입력 모서리 | 12~16dp |
| 간격 체계 | 4/8/12/16/20/24/32dp |
| 그림자 | 아주 약한 그림자 또는 1px 저대비 테두리 |
| 폰트 | Pretendard 또는 Noto Sans KR; 숫자 정렬(tabular figures) 고려 |
| 아이콘 | 한 가지 일관된 라인 아이콘 스타일(Material Symbols 등) |
| 터치 영역 | 최소 44×44 CSS px 수준 권장, 모바일 접근성 준수 |

토큰은 Flutter `ThemeData`, `ColorScheme`, `ThemeExtension` 등으로 중앙 관리한다. 색상은 시작점이며 WCAG 대비 기준을 만족하도록 조정한다. **다크 모드**는 후속 단계에서 동일 토큰 체계로 확장 가능하도록 설계한다.

### 6.3 화면별 Bento 배치

1. **로그인/온보딩:** 중앙 정렬된 소프트 카드, Google 로그인 버튼, 이름 입력, 가족 생성/참여. 불필요한 장식 제거.
2. **월간 달력 홈:** 상단 월 선택 + 요약 벤토 카드(총지출/수입/잔액), 전체 너비 달력 카드, 선택 날짜의 거래 카드, 사용자별 지출 미니 카드. 달력 셀은 금액·선택 상태를 명확히 표현.
3. **거래 등록/수정:** 금액을 가장 크게, 사용자·날짜·카테고리·결제수단을 카드 그룹으로 구성. 카테고리 선택은 첨부 참고 이미지의 아이콘 그리드 형태를 현대적으로 재구성.
4. **거래 상세:** 가맹점·금액 헤더 카드 + 결제 정보 카드 + 수정/삭제 동작. 자동/수동 출처와 승인/취소 상태 표시.
5. **통계:** 사용자별 지출, 카테고리 비율, 월별 추이를 크기가 다른 벤토 카드로 구성. 차트는 간결하게, 수치와 범례 병기.
6. **가족 관리:** 구성원별 아바타·표시 이름·역할 카드, 초대 코드/초대 상태 카드.
7. **카드 관리:** 카드사/마스킹 식별값/연결 사용자/자동 등록 스위치를 카드별 소프트 패널에 표시.
8. **기기 설정:** Android 보조 앱 연결 상태, iOS 단축어 설정 안내, 마지막 수집 시각, 테스트 상태를 분리된 카드로 표시.
9. **검토함:** 파싱 실패·카드 충돌·중복 의심·취소 원거래 미발견 항목을 상태별로 구분한 카드 리스트.
10. **설정:** 프로필·시트 연결·동기화·카테고리·내보내기를 섹션별 벤토 카드로 배치.

### 6.4 공통 UI 컴포넌트

- `BentoCard`: 크기(span), 내부 패딩, 제목/보조 텍스트, 상태 슬롯을 지원하는 공통 카드.
- `SummaryCard`: 월 지출·수입·잔액 표시, 금액 자릿수 변화 대응.
- `CalendarCard` / `DayCell`: 날짜 선택, 일별 금액, 오늘 표시, 접근성 레이블.
- `TransactionTile`: 가맹점·카테고리·사용자·금액·상태.
- `MemberChip` / `CategoryTile`: 사용자 및 카테고리 선택.
- `SoftButton`, `SoftTextField`, `EmptyState`, `StatusIndicator`, `SectionHeader`.
- 공통 컴포넌트는 로딩·빈 상태·오류·긴 텍스트·큰 글꼴 배율을 고려한다.

### 6.5 인터랙션 및 품질 기준

- 카드 전환/선택에 150~250ms 수준의 절제된 모션을 사용하고, OS의 동작 줄이기 설정을 존중한다.
- 모바일 하단 내비게이션(달력·통계·등록·설정)과 명확한 주요 등록 동작 제공.
- Safe Area, iOS Safari PWA 화면 영역, Android Chrome PWA 화면 영역 대응.
- 금액은 `₩`/`원`과 천 단위 구분자를 일관되게 사용하고, 마이너스/취소를 색상만으로 구분하지 않는다.
- 반응형 검증 기준: 360/390/430 CSS px 너비 및 태블릿/데스크톱. 가로 스크롤 없이 주요 기능 사용 가능.
- 스켈레톤 로딩, 저장 성공/실패 피드백, 중복 탭 방지, 접근성 대비/스크린리더 레이블 제공.
- **디자인 검수:** 구현 후 실제 화면 스크린샷을 확인하고, 벤토 레이아웃·간격·타이포그래피·숫자 정렬·가독성을 개선한다. 기능만 구현한 기본 Material 화면을 완료로 간주하지 않는다.

## 7. Google Sheets 스키마

가계부별 스프레드시트에 아래 시트를 둔다. `id`는 UUID, 날짜는 ISO-8601 및 명시적 Asia/Seoul 시간대.

### `Transactions`

| 필드 | 의미 |
|---|---|
| id | UUID |
| householdId | 가계부 ID |
| type | income / expense |
| amount | 양의 정수 KRW |
| occurredAt | 실제 거래 시각 |
| merchant | 가맹점 |
| memo | 사용자 메모 |
| categoryId | 카테고리 ID |
| memberId | 지출 사용자 ID |
| cardId | 카드 ID (수동/현금이면 null) |
| source | manual / android_sms / ios_shortcut |
| status | approved / cancelled / review_required |
| fingerprint | 중복 판정 키 |
| originalTransactionId | 취소 대상 거래 ID |
| createdAt, updatedAt, updatedBy | 감사 정보 |
| deletedAt | 소프트 삭제 |

### `Members`
`id, householdId, googleSubject, email, displayName, role, joinedAt, active`

### `Cards`
`id, householdId, issuer, senderAllowlist, maskedIdentifier, memberId, enabled, createdAt`

### `Categories`
`id, householdId, name, icon, type, sortOrder, enabled`

### `Devices`
`id, householdId, memberId, platform, tokenHash, enabled, lastSeenAt, createdAt`

### `Invites` (후속 기능)
`id, householdId, codeHash, role, expiresAt, maxUses, usedCount` — MVP에서는 Google Sheets 수동 공유로 대체.

### `AuditLog` (선택)
`id, actorId, action, entityType, entityId, timestamp, summary`

> 운영 초기에는 시트 ID/가계부 메타데이터를 GAS Script Properties에 저장할 수 있으나, 다중 가족 서비스 확장 시 별도 메타데이터 저장소가 필요하다. Script Properties에 평문 수집 토큰을 저장하지 않는다.

## 8. 카드 SMS 파싱 규칙

### 8.1 제공된 실제 예시 — 하나카드

**형식 A: 항목별 상세 승인 안내**

```text
승인
금액 13,200원
카드 하나3*8*
손님명 염*준
거래종류 신용
거래구분 일시불
사용처 쿠팡이츠
거래시간 10/10 20:14
누적금액 1,724,480원
```

**형식 B: 일반 SMS**

```text
[Web발신]
하나3*8*승인 염*준
8,800원 일시불 10/12
18:31 (주)현대마트둔촌
누적1,824,135원
```

두 형식 모두 아래 필드 추출:
- `issuer=하나카드`, `maskedIdentifier=하나3*8*`
- `approvalType=approved`, `amount=13200 / 8800`
- `merchant=쿠팡이츠 / (주)현대마트둔촌`
- `occurredAt=수신 연도 + 10/10 20:14 / 10/12 18:31`
- `installment=일시불`, `cumulativeAmount`는 거래 금액이 **아님**.

**중요:** 스크린샷에서 보이는 상세 안내는 실제 SMS 원문과 다를 수 있다. 수집된 텍스트로 테스트 케이스를 확보한다. 문자에 연도가 없으므로 연말/연초 경계에서 수신시각 기준 가장 합리적인 연도를 선택하고 애매하면 검토함으로 보낸다.

### 8.2 파서 구현 원칙

- `SmsParser` 인터페이스와 `HanaCardParser` 등 카드사별 전략 클래스로 분리.
- 발신번호 allowlist 검증 → 승인/취소 유형 검증 → 카드 식별 문자열 매칭 → 금액/날짜/가맹점 파싱.
- **금액은 `승인` 문맥에서만** 추출. `누적...원`을 거래 금액으로 사용 금지.
- 문자 속 이름(예: 염*준)은 카드 매핑 보조 정보일 뿐 단독 식별 기준이 아니다.
- 카드 식별 문자열이 여러 카드에 매칭되면 임의 선택하지 않고 검토함으로 이동.
- 취소 SMS는 원 승인과 매칭해 `cancelled` 처리. 매칭 불가 시 별도 검토 항목 생성. 원 승인과 취소를 모두 지출로 더하지 않는다.
- 중복 방지는 발신자/카드/금액/가맹점/거래일시/승인번호(있을 때)를 정규화한 fingerprint + 짧은 시간대의 재전송 방지. **동일 금액의 별도 정상 결제는 합치지 않도록** 신중히 설계.
- API에 들어오는 문자열은 악의적 입력으로 취급. Sheets 수식 주입 방지(`=`, `+`, `-`, `@` 등 문자열 처리), 길이 제한, 로깅 마스킹.

### 8.3 자동 카테고리

초기 규칙 예시: `쿠팡이츠 → 식비`, `현대마트 → 생활용품(사용자 수정 가능)`. 매칭 안 되면 `미분류`.

## 9. 실제 데이터 API 및 SMS 계약

### 9.1 웹앱 CRUD

- 웹앱은 Google Sheets API `spreadsheets.values.get`, `batchGet`, `append`, `batchUpdate` 및 필요한 `spreadsheets.batchUpdate`를 사용한다.
- `transactions.list/create/update/delete`, `cards.list/upsert` 등은 **Flutter 내부 Repository 메서드 이름**이며 GAS action이 아니다.
- Google OAuth 사용자 토큰의 시트 공유 권한에 따라 Google API가 읽기/쓰기를 허용한다.
- 시트 행 번호를 영구 ID로 사용하지 않는다. UUID 열로 찾고 변경 전 `version`/`updatedAt`을 비교한다. 단, Sheets API는 완전한 원자적 조건부 갱신을 제공하지 않으므로 동시 충돌은 최선 노력이며 엄격한 보장이 필요하면 백엔드 변경.
- 가계부 소유자가 시트 공유를 해제하면 가족 접근이 즉시 차단되는지 실기기 테스트.

### 9.2 SMS 수집 API (GAS `doPost` 하나)

```json
{
  "action": "sms.ingest",
  "deviceId": "device-uuid",
  "ingestToken": "EXAMPLE_ONLY_REPLACE_WITH_RANDOM_SECRET",
  "messageId": "local-unique-id",
  "sender": "EXAMPLE_SENDER",
  "receivedAt": "2026-10-12T18:31:00+09:00",
  "body": "[Web발신]\n하나3*8*승인 염*준\n8,800원 일시불 10/12\n18:31 (주)현대마트둔촌\n누적1,824,135원"
}
```

응답 코드: `CREATED`, `IGNORED_CARD`, `DUPLICATE`, `REVIEW_REQUIRED`, `UNAUTHORIZED`, `INVALID_FORMAT`, `RETRYABLE_ERROR`.

- 실제 카드 발신번호는 사용자가 등록한 값만 사용하고, 예시 번호를 운영 allowlist에 넣지 않는다.
- iOS 단축어가 원문/발신번호/고유 메시지 ID를 모두 제공하지 않을 수 있으므로 **제공되는 필드만 수집**하고 누락 필드는 별도 `deviceId + 본문 해시 + 수신 시각 버킷` 등으로 처리한다. 수신 시각이 없으면 자동 거래시각 정확도를 보장하지 않는다.
- GAS HTTP 응답 코드 커스터마이징이 제한될 수 있으므로 JSON 본문 `ok/code`로 상태 판정하고 리다이렉트 및 타임아웃을 테스트한다.
- 전송 토큰은 사용자마다 별도 발급하고 iOS 단축어에 직접 입력하는 MVP 설정 절차를 문서화한다. **웹앱에서 GAS로 기기 토큰 등록 API를 호출하는 구조는 사용하지 않는다.** 최초 발급은 소유자 GAS 설정 도구/관리 시트로 수동 진행한다.

## 10. Android SMS 수집 보조 앱

- Kotlin으로 작성. 별도 UI는 연결 상태/권한/최근 전송/실패 재시도 정도만 제공.
- `RECEIVE_SMS` 권한과 SMS 브로드캐스트 수신을 검토. `READ_SMS`는 과거 문자 읽기가 필요하지 않으면 요청하지 않는다.
- 수신한 multipart SMS 재조립, 발신번호 정규화, 허용 발신자 선필터, HTTPS 전송.
- 앱 시작 시 가계부 MVP에서는 소유자 설정 절차에서 생성한 **기기별 토큰을 사용자가 보조 앱에 등록**한다. QR/일회용 연결 코드는 안전한 교환 엔드포인트를 설계한 후 확장한다.
- 네트워크 실패 시 로컬 암호화 큐에 저장, 지수 백오프 재시도. 성공 시 삭제. 재부팅/백그라운드 제한 테스트.
- Android의 브로드캐스트/백그라운드 실행 제약에 맞게 WorkManager 사용을 검토. 즉시 전송을 무조건 보장하지 않는다.
- 알림·SMS에 포함된 민감 정보의 로깅 금지. 사용자가 수집 ON/OFF 가능.
- 대상: Galaxy S25 실제 기기, Android 16 및 해당 One UI 버전.

## 11. iOS 단축어 연동

- iPhone 16 Pro에서 **단축어 → 자동화 → 메시지 수신** 트리거 구성.
- 카드사 발신자 조건으로 좁히고, 메시지 입력 변수에서 본문을 받아 HTTPS POST로 `sms.ingest` 호출.
- 사용자별 기기 토큰을 단축어에 설정해야 하므로 **공유/노출 주의**. 토큰 폐기·재발급 지원.
- 단축어가 실제 메시지 본문을 전달하는지, 특정 발신자 조건이 맞는지, 자동 실행 시 확인이 필요한지 실기기 검증.
- SMS 수신 트리거가 지원하지 않는 형태의 메시지는 자동 등록 실패 가능. 수동 공유/붙여넣기 등록을 대체 경로로 제공.
- **PWA 자체에서 SMS를 읽을 수 없음**. 앱스토어 배포는 불필요하지만 단축어 설정은 별도 작업.

## 12. 디렉터리 구조 제안

```text
family-budget/
  README.md
  docs/
    architecture.md
    setup-google.md
    setup-ios-shortcuts.md
    setup-android-sms.md
    api-contract.md
    security.md
  apps/
    web/                     # Flutter Web PWA
      lib/
        app/
        core/
        features/
          auth/
          onboarding/
          calendar/
          transactions/
          statistics/
          family/
          cards/
          settings/
      test/
    android_sms_companion/   # Kotlin Android 앱
  backend/
    gas/
      src/
        api/
        auth/
        sheets/
        parsers/
        services/
      tests/
  scripts/
  .gitignore
```

비밀키, OAuth 토큰, 개인 결제 문자, 실제 시트 ID는 Git에 커밋하지 않는다. `.env.example`/샘플 설정만 제공.

## 12.1 개발자 사전 검증에서 반드시 막아야 할 오류

- PWA에서 Android `RECEIVE_SMS` 권한을 요청하지 않는다.
- iOS에서 별도 앱 없이 모든 SMS를 무조건 자동 읽는다고 약속하지 않는다.
- Google Sheets 공유 초대와 앱 내 `Members` 레코드를 동일한 접근 권한으로 취급하지 않는다.
- 공개 GAS 엔드포인트에 고정된 비밀키를 Flutter 웹 코드로 포함하지 않는다.
- `no-cors` fetch 성공을 거래 저장 성공으로 간주하지 않는다(응답 확인 불가).
- 카드사 발신번호는 SMS 앱 표시명과 실제 sender 주소가 다를 수 있으므로 실제 수신 값으로 검증한다.
- 동일 금액/가맹점/분 단위 거래를 무조건 중복 처리하지 않는다.
- Android SMS 앱 직접 설치와 Android Google Play 등록을 같은 난이도로 취급하지 않는다.
- iOS Safari와 홈 화면 PWA의 OAuth 팝업/쿠키/스토리지 동작을 같다고 가정하지 않는다.

## 13. 개발 단계 및 완료 기준

### Phase 0 — 위험 요소 PoC (가장 먼저)
- [ ] Flutter Web PWA가 Galaxy S25 Chrome / iPhone 16 Pro Safari에서 정상 실행/홈 화면 추가되는지 확인.
- [ ] iOS 단축어와 Android HTTP 클라이언트에서 GAS `doPost` JSON 전송/리다이렉트/응답 확인. **웹 브라우저는 Sheets API 직접 호출**을 검증.
- [ ] GIS 웹 OAuth → Google Sheets API 읽기/쓰기 및 가족 공유 ACL 확인(갤럭시 Chrome, 아이폰 Safari, iOS 홈 화면 PWA 각각).
- [ ] iOS 단축어에서 하나카드 SMS 본문을 수집해 테스트 엔드포인트로 전송 가능한지 확인.
- [ ] Android 보조 앱의 SMS 수신/백그라운드 전송 검증.
- [ ] 실패 시 대안 및 추가 비용/구성 변경을 문서화.

### Phase 1 — 기본 가계부 MVP
- [ ] Google 로그인/Sheets OAuth/이름/수동 시트 공유 기반 가족 참여/연결 상태.
- [ ] 달력, 거래 목록, 수동 등록/수정/삭제.
- [ ] 사용자별·카테고리별 합계.
- [ ] 기본 카테고리 및 모바일 UI.

### Phase 2 — 자동 수집
- [ ] 카드 관리 및 필터링.
- [ ] 하나카드 두 형식 파서.
- [ ] Android SMS 보조 앱.
- [ ] iOS 단축어 가이드 및 템플릿.
- [ ] 중복/취소/검토함/전송 실패 재시도.

### Phase 3 — 품질/보안/배포
- [ ] Google 시트 공유 권한 테스트, SMS 기기 토큰 철회, 요청량 제한/할당량 방어.
- [ ] 동시 수정/중복 SMS/네트워크 장애 테스트.
- [ ] 개인정보 최소 저장 및 삭제/내보내기.
- [ ] Firebase Hosting 배포 및 PWA 설치 가이드.

## 14. 테스트 케이스 (필수)

1. 허용 카드 `하나3*8*` 승인 SMS → 정확한 금액/가맹점/사용자 기록.
2. 비허용 카드 SMS → `IGNORED_CARD`, 원장에 기록 없음.
3. 카드사 발신번호 불일치 → 등록 거부.
4. 상세형/일반형 SMS 각각 파싱 성공.
5. `누적1,824,135원`을 거래 금액으로 오인하지 않음.
6. 동일 SMS 재전송 → 중복 기록 없음.
7. 같은 날 같은 금액의 서로 다른 정상 거래 → 각각 기록.
8. 승인 취소 → 원 승인에 연결되고 통계에서 제외/차감.
9. 취소 먼저 도착 → 검토함.
10. 카드 마스킹 충돌 → 검토함, 임의 사용자 지정 금지.
11. 12월 31일/1월 1일 문자 연도 추론.
12. 가족 A 구성원이 공유받지 않은 가족 B 시트에 Sheets API로 접근 불가.
13. Google Sheets Viewer 권한 사용자는 거래 수정 불가(앱 내부 viewer 표시만으로 차단했다고 간주하지 않음).
14. 토큰 없는 SMS 수집 요청 거부, 폐기 토큰 거부.
15. 네트워크 끊김/재전송 후 원장 한 번만 반영.
16. iOS 홈 화면 PWA에서 입력/달력/로그인 정상 동작.

## 15. Codex 에이전트 실행 지시 프롬프트

다음 내용을 Codex에 그대로 전달한다.

```text
이 저장소에 docs/family_budget_development_spec.md 명세를 기준으로 가족 공유 가계부를 개발해줘.

우선 Phase 0 기술 검증부터 진행하고, GIS OAuth/Google Sheets API 접근·GAS SMS 전용 리다이렉트·iOS 단축어 자동화·Android SMS 수신의 실현 가능성을 검증 가능한 코드/절차로 제시해줘. 검증하지 않은 플랫폼 기능은 동작한다고 단정하지 마.

UI 디자인 필수: Bento Grid + Soft Minimal(벤토 + 소프트 미니멀). 명세서 6장의 디자인 토큰, 벤토 카드 레이아웃, 공통 컴포넌트, 모바일 반응형 기준을 구현해. 기본 Material 화면만으로 완료 처리하지 마.\n\n기술 스택: Flutter Web PWA + Riverpod + go_router, Google Identity Services OAuth, 브라우저 Google Sheets REST API 직접 호출, SMS 전용 Google Apps Script, Android Kotlin SMS 보조 앱, iOS 단축어 연동. 웹앱에서 GAS 범용 REST API를 직접 호출하지 마.

서버를 직접 운영하지 않고, 카드사 SMS 중 허용한 카드만 자동 등록해야 해. 하나카드 상세형/일반형 두 가지 문자 형식을 우선 지원하고, 수동 등록/수정/삭제, 달력, 사용자별 지출, 가족 공유, 카드 설정을 구현해줘.

작업 방식:
1. 먼저 프로젝트 구조, 보안 위협 모델, Google Sheets 공유 ACL 모델, 단계별 구현 계획을 README와 docs에 작성해. Google OAuth/Sheets 권한과 SMS 기기 토큰을 분리해.
2. Phase 0 PoC를 구현하고 Galaxy S25 및 iPhone 16 Pro에서만 확인 가능한 항목은 체크리스트로 분리해. iOS 자동 SMS 수집은 실기기 검증 전 완료 처리하지 마.
3. 성공한 기술 검증을 기준으로 Phase 1부터 작은 단위로 개발해.
4. 파서, 카드 필터, 중복 방지, 승인 취소, 접근 권한에 대한 자동 테스트를 작성해.
5. 비밀키/실제 카드 정보는 코드나 Git에 저장하지 마. 샘플 데이터만 사용해.
6. 핵심 화면의 Bento + Soft Minimal 스타일을 스크린샷 기준으로 검수하고, 디자인 토큰과 공통 컴포넌트를 재사용해.\n7. Firebase/Google 계정에서 사용자가 직접 수행해야 하는 설정은 명령어와 화면 절차로 자세히 문서화해.
8. 단계별 완료 시 구현 내용, 실행 방법, 남은 위험과 다음 작업을 요약해.

우선 Phase 0 계획과 저장소 뼈대를 만들어줘.
```

## 15.1 최종 수용 기준 및 실패 시 대안

**기능별 완료 기준**

- Galaxy S25: Chrome PWA 로그인/시트 수정 성공 + 보조 APK로 허용 카드 SMS 자동 전송 및 재시도 성공.
- iPhone 16 Pro: Safari와 홈 화면 PWA에서 로그인/시트 수정 성공 + SMS 수신 자동화가 사용자 개입 없이 GAS에 POST하고 기록되는지 실제 테스트. 실패하면 iOS 자동 등록은 **제한 기능**으로 표시하고 단축어 수동 실행/문자 붙여넣기 대안을 제공.
- 공동 시트: 서로 다른 두 Google 계정에서 거래가 공유되고, 시트 Viewer 권한은 쓰기가 거절되어야 한다.
- 사용자 이름: 로그인 Google 계정과 별도 표시 이름 변경 가능. 카드별 귀속 사용자 설정 가능.
- 카드 필터: 등록하지 않은 카드 거래가 원장에 기록되지 않으며, 불명확한 식별값은 자동 귀속하지 않는다.
- 재시도: 전송 성공 여부를 확인할 수 없으면 멱등성 키로 재시도하고 중복 지출이 생기지 않아야 한다.

**대안 전환 기준:** GIS OAuth가 iOS 홈 화면 PWA에서 안정적으로 동작하지 않으면 Safari 브라우저 사용을 먼저 지원하고, 홈 화면 설치는 보류한다. GAS 문자 전송/응답 검증 실패 시 우선 수동 입력으로 운영하고, 별도 관리형 엔드포인트 도입 여부를 사용자에게 확인받는다. 임의로 유료 서비스를 추가하지 않는다.

## 16. 추후 확장 아이디어

- 다른 카드사 파서 플러그인, 할부/정기결제, 월 예산, CSV 내보내기.
- 가족별 개별 시트 자동 생성 및 셀프서비스 연결, 자동 Drive 공유/초대(추가 OAuth 권한 및 공개 검증 필요).
- 가맹점 규칙 학습 및 카테고리 사용자 지정.
- 자동 등록 실패 알림 및 SMS 수집 상태 대시보드.

---

**최종 판단:** Flutter Web PWA + **브라우저 Google Sheets API** + **SMS 전용 GAS** + Android 보조 앱 + iOS 단축어는 소규모 가족 가계부의 현실적인 MVP다. iOS SMS 자동화, 두 기기의 OAuth 동작, GAS 리다이렉트는 Phase 0 실기기 검증이 필수이며 검증 전 자동화를 보장하지 않는다.
