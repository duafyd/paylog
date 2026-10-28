# SMS 수집 운영 설정

웹은 Google OAuth로 Sheets API를 직접 호출한다. 아래 GAS는 SMS 수집 전용이며 웹 CRUD나 토큰 발급 HTTP API를 제공하지 않는다. Android 1.3.0에서 웹 관리 화면에서 기기 키를 로컬 생성하고 Sheets에 해시를 등록하는 간편 연결을 지원한다. 아직 실제 GAS 계정에 배포하거나 HTTP 리다이렉트를 검증하지 않았다.

## GAS 준비

1. 웹에서 만든 가계부의 소유자 Google 계정으로 새 Apps Script 프로젝트를 만든다.
2. `node services/sms/build.mjs`를 실행하고 `services/sms/gas/Code.gs`를 프로젝트에 복사한다. 프로젝트 설정에서 manifest 표시를 켜고 `appsscript.json`도 복사한다.
3. 프로젝트 Script Properties에 `SPREADSHEET_ID`를 설정한다. 평문 기기 토큰을 Properties에 넣지 않는다.
4. 연결된 Cloud 프로젝트에 Sheets API를 활성화한다. 소유자 권한으로 `setupSmsTables`를 한 번 실행한다. 이 함수는 없는 관리 탭만 추가하고 기존 탭을 덮어쓰지 않는다. 부분 실패 시 생성된 탭과 헤더를 확인하여 manifest의 `TABLE_HEADERS`와 맞춘다. 무작정 재실행해 기존 데이터를 지우지 않는다.
5. 웹 설정 → 가계부 관리 → Categories에서 필요한 분류를 추가한다. 아이콘 키는 화면에 안내한 기본 카테고리 ID, 이름은 `식비`, `생활`, `기타`를 권장한다. 기존 거래의 기본 문자열 ID도 계속 읽을 수 있다. SMS는 실제 Categories UUID만 사용한다.
6. Cards에 UUID, 동일 householdId, issuer=하나카드, **실제 발신번호**(여럿이면 쉼표), maskedIdentifier, 실제 Members UUID, enabled=true, createdAt ISO 시각을 입력한다. 웹 관리 화면으로도 추가할 수 있다. 예시 번호를 운영 허용 목록에 넣지 않는다. 중복 마스킹은 검토함으로 보낸다.
7. **Android 권장:** 웹 관리 → 기기 → Android 간편 연결에서 가족과 GAS 주소를 선택해 연결 파일을 저장한다. UUID·랜덤 키·해시 등록과 카드 발신번호 복사가 자동 처리된다. 앱에서 파일을 선택하고 문자 권한을 허용한 뒤 파일을 삭제한다. 이 방법이면 아래 수동 토큰 등록은 생략한다. 휴대폰마다 별도로 생성한다.

   **iOS 권장:** 같은 관리 → 기기 화면의 iPhone 간편 연결로 설정 파일을 만든다. [단축어 레시피](../ios/sms-shortcut-template.json)를 따른다.

   **수동 등록 대체 경로:** 새 랜덤 비밀값을 로컬에서 `openssl rand -hex 32`로 만들고 안전하게 보관한다. 신뢰할 수 있는 로컬 비밀 입력 도구로 SHA-256을 계산한다. 실제 값을 셸 명령 인자/기록에 입력하지 않는다. 토큰을 Git·로그·스크린샷에 올리지 않는다.
8. Devices에는 새 UUID, householdId, memberId, platform=`android`/`ios`, **해시만** tokenHash에 입력하고 enabled=true로 설정한다. 원본 토큰은 해당 기기에만 입력한다. 폐기는 enabled=false 또는 tokenHash 교체로 처리한다. 웹에는 해시도 표시하지 않는다.
9. 웹앱 배포에서 **실행 사용자=소유자**, 접근=기기의 무인 HTTP 요청을 허용하는 설정으로 `/exec` URL을 만든다. 공개 접근을 제한하는 Workspace 정책에서는 이 방식이 불가능할 수 있다. 설정 가능한 계정 또는 별도 인증 백엔드가 필요하다. 새 코드 버전마다 배포 버전을 갱신한다.

## 계약과 복구

요청 예시는 원본 명세 9.2절을 따른다. JSON `ok/code`로 판정하며 HTTP 200만으로 성공 처리하지 않는다. GAS ContentService의 응답 리다이렉트 대상은 `script.googleusercontent.com`이다. Android 앱은 원본 POST 후 해당 호스트로 GET하여 결과만 받으며 비밀 JSON을 리다이렉트에 재전송하지 않는다.

인증 → 활성 Members·Devices 확인 → 기기별 분당 30회 캐시 기반 제한 → 입력 길이·수신 시각 검증 → 실제 발신자·카드 매핑 → 파싱 순서다. 수신 시각은 명시적 오프셋을 포함해야 하며 7일 이내 재시도만 받는다. Apps Script 캐시 제한은 할당량 보호의 보조 수단이며 엄격한 방화벽/사용량 보장을 제공하지 않는다. 악의적 공개 요청 자체가 GAS 실행 할당량을 소비할 수 있으므로 공개 서비스로 확장할 경우 별도 인증 게이트웨이가 필요하다.

Messages에는 기기 범위 중복 키·본문 해시·결과·수신 시각만 보관한다. 원문·평문 토큰은 저장/로그하지 않는다. Review에는 추출한 최소 거래 후보 또는 null만 저장한다. messageId가 없는 iOS 입력은 중복 결제 오판을 막기 위해 자동 승인하지 않고 검토한다. 같은 ID+다른 본문은 거부한다. 같은 카드·금액·가맹점·거래 분의 승인이 다른 메시지 ID로 다시 들어오면 POSSIBLE_DUPLICATE 검토로 보낸다. 같은 금액이어도 시각/가맹점/카드가 다르면 별도 거래다. 삭제/취소된 기존 거래의 지문도 재입력 방지에 사용한다.

거래 UUID는 요청 중복 키에서 결정되므로 거래 저장 후 응답이나 receipt 저장이 실패해도 재전송 시 추가 거래를 만들지 않는다. 취소는 먼저 취소 마커를 저장하고 원 승인을 취소 처리한다. 중단 후 재전송은 마커를 찾아 원 승인 갱신을 마무리한다. 원 승인 후보가 여럿이거나 없으면 검토함으로 보낸다. 엄격한 원자성은 없으며 중간 단계에서는 일시적으로 합계가 갱신 전일 수 있다. 원 승인 매칭은 동일 카드/금액/가맹점과 30일 이내 승인만 후보로 삼는다.

검토함 처리: 후보를 확인하여 웹 수동 등록으로 올바른 거래를 저장한 뒤, Review의 resolution에 확인된 거래 UUID를 입력한다. 무시할 항목은 `ignored`를 입력한다. 원문이 필요한 경우 기기에서 직접 확인한다. 원장을 삭제하려면 Google Drive에서 시트를 삭제하고 GAS 배포 중지·기기 비활성화·각 기기 대기열 삭제도 수행한다. CSV 내보내기는 현재 승인된 활성 거래만 포함하며 기기 토큰은 포함하지 않는다.

Google 공유 ACL은 GAS 소유자 실행과 별개다. 기기 토큰 철회는 Devices로 즉시 차단하고, 가족 웹 접근 철회는 Sheets 공유 메뉴에서 수행한다. 웹·SMS 간 동시 쓰기에 GAS LockService가 공동 잠금을 제공하지 않는다. 엄격한 트랜잭션이 필요하면 백엔드 저장소를 전환한다.

## 자동 검증

```sh
node --test services/sms/test/*.test.js
node services/sms/build.mjs
git diff --exit-code -- services/sms/gas/Code.gs
```

단위 테스트는 실제 Google 인증·GAS URL·계정 할당량·리다이렉트·SMS 실수신을 검증하지 않는다. 운영 계정 연결 후에는 먼저 별도 테스트 시트에서 승인/취소/응답 단절/토큰 철회를 검증한다.
