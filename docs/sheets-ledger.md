# Sheets 원장 연결 · 읽기와 수동 등록

이번 단계는 로그인 PoC와 별도로 실제 원장 Repository를 연결한다. 기본 실행은 여전히 샘플 모드이며 **공개 웹 클라이언트 ID가 아직 설정되지 않아 실제 Google 계정/API 검증은 미실행**이다. [Google 설정](setup-google.md)을 먼저 완료한다. 토큰·시트 ID·금융 데이터는 브라우저 저장소에 영구 저장하지 않는다.

## 사용 흐름

1. 설정 → Google 연결 검증 → Google 로그인 → Sheets 권한 동의.
2. 아래 **달력에 실제 원장 연결**에서 기존 시트 ID/URL을 입력하거나 **새 가계부 템플릿 만들기**를 선택한다.
3. 새 템플릿은 확인창에 동의한 경우에만 생성한다. `Transactions`, `Members` 탭과 현재 계정의 Members UUID를 만든다. 샘플 거래를 복사하거나 기존 시트를 자동 변경하지 않는다.
4. 연결 성공 후 달력·통계·등록이 Sheets 모드로 전환된다. 상단 배지와 원장 상태 카드에서 확인할 수 있다. 기본 샘플 거래는 합쳐지지 않는다.
5. 수동 등록은 Google에 RAW append한 다음 재조회로 UUID·금액·입력 내용이 일치해야 성공 처리한다. 다른 기기의 변경은 **원장 새로고침**으로 가져온다. 실시간 구독은 없다.
6. 새로고침/탭 종료로 로그인·연결 상태는 사라진다. 같은 계정으로 로그인하고 같은 시트 ID를 다시 연결하면 서버 기록을 읽는다. 시트 데이터 자체를 삭제하지 않는다.
7. **샘플 모드로 돌아가기**는 계정 권한을 철회하지 않고 원장 표시만 샘플로 바꾼다. **Google 연결 해제**는 토큰/계정을 지우고 원장 표시를 샘플로 되돌린 후 Google 권한 철회를 요청한다.

가족 시트 공유는 Google Sheets 공유 메뉴에서 수동으로 한다. Google 공유 권한과 Members UUID 매핑은 별개다. 가족 가입/구성원 관리 UI는 아직 없으며, 현재 템플릿에는 생성자 1명만 등록된다. 공유받은 계정이 Members에 연결되지 않았으면 읽기 전용으로 동작한다.

## 시트 계약

### Transactions

원본 명세의 A:R 18개 열을 순서대로 유지한다. 수동 등록의 결제수단을 보존하기 위해 S열 **`paymentMethod`**를 추가했다.

```text
id, householdId, type, amount, occurredAt, merchant, memo, categoryId,
memberId, cardId, source, status, fingerprint, originalTransactionId,
createdAt, updatedAt, updatedBy, deletedAt, paymentMethod
```

- 새 템플릿은 19개 헤더를 생성한다. 기존 18개 헤더는 읽기 전용으로만 열고 결제수단을 `미지정`으로 표시한다. 기존 시트를 자동 마이그레이션하지 않는다.
- 거래 ID·가계부 ID·멤버 ID는 UUID를 사용한다. 표시 이름으로 거래를 연결하지 않는다. 동명이인 레이블에는 이메일을 붙이고, 이메일이 없으면 UUID 앞부분으로 구분한다. `updatedBy`는 현재 로그인 계정에 매핑된 Members UUID이며 거래에 선택한 사용자와 다를 수 있다.
- 금액은 1~999,999,999,999원 정수다. 시트에서 중복 거래 ID, 다른 가계부 ID, 잘못된 금액/날짜, 없는 멤버/카테고리를 발견하면 전체 로딩을 실패시킨다. 조용히 행을 버리거나 0원으로 처리하지 않는다. 기존 정상 스냅샷이 있으면 유지하고 실패를 안내한다.
- 이번 버전은 앱의 기본 카테고리 ID `food/groceries/cafe/transport/shopping/health/leisure/other/salary/bonus`만 지원한다. 사용자 정의 Categories 탭/UUID 매핑은 후속 범위다. 임의 카테고리는 `other`로 바꾸지 않고 오류로 보고한다.
- `approved` 중 `deletedAt`이 없는 거래만 요약에 포함한다. `cancelled`, `review_required`, 소프트 삭제는 제외 건수를 안내한다. 취소 원거래 매칭과 검토함 기능은 구현하지 않았다.
- 거래 시각은 오프셋이 있는 ISO-8601로 읽고 **Asia/Seoul 날짜·시간**으로 화면에 표시한다. 입력한 날짜·시간도 서울 시각으로 저장한다. 브라우저 시간대가 달라도 일별 합계를 같은 날짜로 맞춘다.
- `paymentMethod`는 `카드/현금/계좌이체` 중 하나다. 문자열은 `valueInputOption=RAW`로 저장해 `=...` 등을 수식으로 실행하지 않는다.

### Members

```text
id, householdId, googleSubject, email, displayName, role, joinedAt, active
```

UUID 중복이나 여러 가계부의 Members가 섞인 시트는 거부한다. `active`는 true/false다. 같은 Google subject가 둘 이상의 활성 Members와 연결되면 임의 선택하지 않는다.

활성 Members 매핑이 없거나 `role=viewer`이면 앱은 쓰기를 막는다. **이 검사는 UI 동작 기준이며 실제 보안 권한은 Google 공유 ACL이다.** `role=owner`라고 적혀 있어도 Google Viewer 공유 권한이면 Google API가 쓰기를 거부해야 하며, 이 실제 ACL 검증은 아직 수행하지 않았다.

이전 연결 PoC 시트(`connection-probe`, 임시 subject memberId, Members 없음)는 실제 원장으로 사용할 수 없다. 새 원장 템플릿으로 시작한다.

## 응답 단절과 중복 방지

- 등록 폼의 UUID는 저장 버튼을 다시 눌러도 바꾸지 않는다. 저장 중에는 중복 탭과 입력을 차단한다.
- POST 응답이 끊기거나 저장 후 재조회가 실패하면 성공으로 표시하지 않는다. 입력을 고정하고 **저장 결과 다시 확인**을 제공한다.
- 재확인에서는 먼저 GET으로 UUID를 찾는다. 같은 내용이 이미 있으면 POST 없이 성공 처리한다. 같은 UUID의 다른 내용이 있으면 덮어쓰지 않는다.
- 이전 POST 결과가 불명확한데 UUID가 아직 보이지 않으면 다시 쓰지 않고 수동 확인을 요청한다. 서버의 지연 완료 때문에 조회 직후 다시 POST하는 것도 중복을 만들 수 있기 때문이다.
- Google의 명확한 401/403/404/429 거부는 별도 오류로 안내한다. 로컬 거래를 먼저 추가하지 않는다.
- 불명확한 작업 목록은 현재 메모리에만 있다. **탭 종료·새로고침·다른 원장 재연결로 상태를 잃은 뒤 새 UUID로 같은 내역을 다시 등록하면 중복을 보장할 수 없다.** 시트를 직접 확인한 후 처리해야 한다. Sheets는 원자적 조건부 쓰기/공통 트랜잭션을 제공하지 않는다.

조회는 메타데이터·Members·Transactions를 함께 검증하며, 쓰기 전후 재조회가 있어 API 요청 수가 늘어난다. 소규모 가족 원장을 전제로 하고 대규모 시트·할당량 최적화는 후속이다. 로딩은 완전한 DB 트랜잭션 스냅샷이 아니며 동시 수동 편집을 엄격하게 직렬화하지 못한다.

## 검증과 후속 작업

`flutter test`는 원장 파싱·UUID 매핑·정수 금액·서울 날짜·조회 전용·403·응답 단절·동일 UUID 재확인·샘플 격리·로그아웃 캐시 제거를 검증한다. 모의 GIS/API 웹 번들을 실행한 상태에서 저장소 루트의 `scripts/sheets-ledger-smoke.cjs`로 브라우저 통합 검사를 재현할 수 있다.

```sh
# apps/web에서 모의 전용 번들 생성. 실제 계정 테스트용 ID가 아니다.
flutter build web --release --no-web-resources-cdn \
  --dart-define=GOOGLE_WEB_CLIENT_ID=browser-test.apps.googleusercontent.com \
  --output=build/google-poc
python3 -m http.server 8081 --bind 127.0.0.1 --directory build/google-poc
# 다른 터미널, 저장소 루트 (Playwright 설치는 README 참고)
NODE_PATH=/tmp/paylog-browser-tools/node_modules CHROMIUM_PATH=/usr/bin/chromium \
  node scripts/sheets-ledger-smoke.cjs
```

실제 Google OAuth·CORS·공유 ACL·Galaxy S25/iPhone 16 Pro 실기기 검증이 먼저 필요하다. 다음 기능은 가족 가입/멤버 관리, 사용자 정의 카테고리, 거래 상세·수정·소프트 삭제, 동시 편집/감사 기록, 오프라인/배포 전략이다.
