# Firebase 전환 결정과 계정 설정

결정일: 2026-10-26 (한국 시간). 사용자가 Google 계정 전용 대신 **아이디·비밀번호 회원가입/로그인**으로 최종 변경했다.

## 확정 방향

- 기존 프로젝트 `paylog-c5c2d`, Hosting, Spark 무료 플랜을 유지한다. 별도 결정 없이 결제 수단 등록·Blaze 전환을 하지 않는다.
- Firebase Authentication이 계정과 비밀번호 인증을 담당하고, Cloud Firestore가 가족 원장을 저장한다. Sheets·공유 ACL·GAS·기기 수동 토큰을 대체한다.
- Flutter Web·Riverpod의 달력·거래·통계·CSV 화면을 재사용한다. 아이폰 Safari/홈 화면 웹앱과 갤럭시 Chrome/홈 화면 웹앱을 지원 대상으로 한다.
- 원장 사용 흐름은 **한 명 회원가입/로그인 → 가계부 생성 → 초대 코드 생성 → 다른 한 명 회원가입/로그인 → 코드 입력 → 같은 가계부 사용**이다. 가계부 참여 인원에는 앱 차원의 상한을 두지 않는다. 멤버는 별도 문서로 저장하고 페이지 단위로 조회한다.
- 로그인은 이메일 주소나 Google 계정을 요구하지 않는다. 새 계정 모델의 식별자는 Firebase UID이고 화면 아이디는 로그인 이름이다.

## 이번 구현 상태

`/sign-in`에서 아이디·비밀번호 로그인, 회원가입, 비밀번호 확인, 로그인 복원, 로그아웃을 제공한다. 계정 UID 변경이나 인증 상태 오류 시 이전 원장 캐시를 정리한다. 비밀번호·토큰을 프로필 모델이나 로그에 넣지 않는다. 로그인은 이 탭의 SESSION 지속성을 사용한다.

**Firestore 원장 생성·초대·거래 저장을 구현했다.** 로그인 후 공동 가계부 시작하기에서 생성 또는 참여한다. 한 계정은 현재 한 가계부에 참여한다. 모든 멤버가 공동 거래를 조회·추가·수정·삭제 표시하고 초대할 수 있다. 탈퇴·강제 해제·계정 완전 삭제 UI는 아직 없으며 운영자에게 요청한다. SMS 경로 전환은 아직 미구현이다. 배포 전환 기간에 기존 Sheets 연결은 이전 방식으로 유지한다. 원본 시트의 자동 이전·삭제는 하지 않는다.

## 아이디·비밀번호 처리

- 아이디: 영문으로 시작하는 영문·숫자·밑줄 4~20자. 앞뒤 공백 제거와 소문자 변환을 한 뒤 가입/로그인 모두 같은 값으로 처리한다. 화면에 내부 주소를 노출하지 않는다.
- Firebase Auth의 무료 기본 API는 사용자 이름 인증을 직접 제공하지 않아 Email/Password 공급자를 사용한다. 아이디 `family_one`은 내부 식별용 `family_one@accounts.paylog.invalid`에 일관되게 대응한다. `.invalid`는 예약된 비전달 도메인으로, 사용자 이메일 수집·인증 메일 발송을 위한 주소가 아니다.
- 비밀번호는 가입 시 8~128자이며 확인 입력이 일치해야 한다. 실제 비밀번호의 공백을 임의로 제거하지 않는다. Firebase에 HTTPS로 전달하고 검증·저장은 Firebase Auth에 맡긴다. Firestore, 설정 파일, 앱 로그에 비밀번호를 저장하지 않는다.
- 아이디의 유일성은 동일 내부 주소에 대한 Firebase Auth의 계정 유일성으로 보장한다. 중복 계정을 만들기 위해 별도 클라이언트 username 레지스트리를 쓰지 않는다.
- 이메일을 받지 않으므로 이메일 비밀번호 재설정/이메일 검증 흐름을 제공하지 않는다. 아이디와 비밀번호 분실 시 자동 복구는 지원하지 않는다고 가입 화면에서 안내한다. 복구 기능은 별도 설계가 필요하며 관리자 권한을 웹에 내장하지 않는다.
- 이전 Google-only Firebase 세션은 새 계정으로 복원하지 않고 정리한다. Google 계정을 아이디 계정으로 자동 변환하거나 데이터를 합치지 않는다.

## 소유자가 콘솔에서 할 일

1. [Firebase Authentication 공급자](https://console.firebase.google.com/project/paylog-c5c2d/authentication/providers) → **이메일/비밀번호** → 첫 번째 Email/Password 사용 설정을 켜고 저장한다. **이메일 링크(비밀번호 없는 로그인)**는 사용하지 않는다.
2. 새 UI에는 Google 로그인 버튼이 없으며 Google 제공업체는 새 회원가입/로그인에 필요하지 않다. 공급자 설정에서 Google을 비활성화할 수 있다. 기존 Google OAuth/Sheets 경로와는 별개다.
3. 앱의 공개 Firebase 설정은 이미 등록된 `paylog-web`을 사용한다. 서비스 계정 키나 관리자 비밀키를 웹에 넣지 않는다.
4. [Firestore 데이터베이스](https://console.firebase.google.com/project/paylog-c5c2d/firestore) → 데이터베이스 만들기 → **Standard, 기본 `(default)` 데이터베이스**, 위치는 가능하면 서울 `asia-northeast3`, **프로덕션 모드**를 선택한다. 생성 후 위치는 쉽게 변경할 수 없으므로 확인한다. Spark 무료 플랜을 유지하고 유료 옵션을 켜지 않는다. 이미 기본 데이터베이스가 있다면 재생성하지 않는다.
5. 아래 배포 명령은 **보안 규칙을 먼저 배포**하고 성공한 뒤 웹을 게시한다. 규칙 배포 실패 시 웹 배포를 중단한다. 생성 시 공개 테스트 규칙을 사용하지 않는다.
6. 아래 웹 배포 후 `/sign-in`에서 새 아이디 가입 → 로그아웃 → 같은 아이디 로그인 → 새로고침을 확인한다. Firebase Authentication 사용자 목록에는 내부 식별용 주소가 보이는 것이 정상이다.

```sh
(
  set -e
  cd "$HOME/paylog"
  git fetch origin
  git switch feat/firebase-auth-migration
  git pull --ff-only
  bash scripts/deploy-cloud-shell.sh
)
```

이 회원가입 방식에는 Google OAuth 동의나 Sheets 민감 범위가 필요하지 않다. 현재 단계 테스트를 위해 Firestore 테스트 모드/공개 규칙을 활성화할 필요는 없다.

## Firestore 저장과 무료 운영 조건

- 가족 멤버 UID를 기준으로 Security Rules에서 읽기·쓰기·멤버십 변경을 검증한다. 아이디나 UI 숨김만으로 권한을 부여하지 않는다. 비밀번호를 Firestore에 넣지 않는다.
- 아이디 기반 원장 접근에는 정해진 내부 주소 형식과 password 인증 공급자를 규칙에서 확인한다. 무조건 email_verified=true를 요구하면 이 설계의 계정을 모두 차단하므로 이메일 인증 여부를 가족 권한의 근거로 사용하지 않는다.
- 생성·가입은 원자적 쓰기와 보안 규칙으로 검증한다. 본인이 아닌 UID 추가, 만료/재사용 코드, 다른 가계부 접근, 동시 가입 경쟁을 에뮬레이터에서 시험한다.
- 초대 코드는 보안 난수로 만들고 유효기간·폐기를 지원한다. 유효한 코드로 여러 사람이 참여할 수 있으며 동일 사용자의 중복 참여는 막는다. 코드 원문을 분석 이벤트·URL·로그에 넣지 않는다.
- 가족/월 단위 제한 쿼리와 페이지네이션, 월 변경·계정 종료 시 리스너 해제로 읽기량을 제한한다. 무료 한도 초과 시 오류를 안내하며 무한 재시도하지 않는다.
- Cloud Functions, Storage 첨부, 유료 백업/PITR은 기본 의존성에 넣지 않는다. 기존 시트 데이터는 필요할 때 선택적으로 이전하며 확인 전 원본을 삭제하지 않는다.
- Android 문자 수집은 별도 개편 대상이다. iPhone은 임의 SMS 백그라운드 수집이 불가능하며 단축어 방식은 별도 검증한다. Play Protect 설치 정책은 계정·DB 전환과 별개다.

## 자동 검증

`flutter analyze`, `flutter test`, release 빌드를 수행한다. `scripts/firebase-auth-smoke.cjs`는 실제 공식 FlutterFire JS SDK와 모의 Auth REST 응답으로 입력 확인·가입·아이디 정규화·잘못된 비밀번호·중복 아이디·세션 복원·로그아웃을 검증한다. 운영 Firebase에 테스트 계정을 만들지 않는다. SDK HTTPS 다운로드의 인증서 검증을 끄지 않는다. 운영 Email/Password 설정과 실제 iPhone/Galaxy 브라우저 동작은 별도 검증 대상이다.

```sh
python3 -m http.server 8096 --directory apps/web/build/web
# 별도 터미널, Playwright와 Chromium이 있는 환경
PAYLOG_BASE_URL=http://127.0.0.1:8096 node scripts/firebase-auth-smoke.cjs
```

## 데이터 모델과 조회 범위

- `profiles/{uid}`: 현재 가계부 ID·아이디·생성 시각. 자신의 문서만 읽는다.
- `households/{id}` 및 `members/{uid}`: 가계부와 개별 멤버. 인원수 상한이나 모든 멤버를 넣은 배열은 없다. 멤버 조회는 50명씩 이어서 읽는다.
- `invites/{sha256(code)}`: 192비트 보안 난수 코드의 해시·발급자·가계부·만료 시각. 약 24시간 동안 여러 사람이 사용한다. 초대 목록 조회는 금지한다. 현재 화면의 발급 코드 폐기/재발급을 지원하며 새로고침한 뒤에는 원문을 복구하지 않는다. 과거 별도 발급 코드는 만료 전까지 유효할 수 있다.
- `households/{id}/transactions/{id}`: 거래와 작성/수정 UID·시각·버전·삭제 표시. 같은 UUID 재시도는 같은 결과를 확인하고, 버전이 다른 편집은 충돌로 거절한다. 물리 삭제는 클라이언트에서 금지한다.
- 거래는 서울 기준 선택 월을 500개씩 조회한다. **합계·통계·CSV는 불러온 기록만 포함**한다. 더 보기가 남으면 화면에서 안내한다. 다른 사용자의 변경으로 첫 페이지가 다시 동기화되면 추가 페이지는 다시 불러와야 한다. 월 변경 시 선택 월의 기록만 남는다.
- 영구 Firestore 오프라인 캐시를 사용하지 않는다. 실시간 리스너는 현재 월 첫 페이지에 유지하며 로그아웃·월 변경 시 해제한다. 서버 확인 전 오프라인 변경을 저장 완료로 표시하지 않는다.
- 무료 Firestore 기본 할당량은 현재 문서 읽기 50,000/일, 쓰기 20,000/일, 삭제 20,000/일, 저장 1GiB다. 두 사람이 일상적으로 쓰는 가계부에는 여유가 있지만 무제한은 아니다. 실시간 업데이트·보안 규칙 확인·페이지 조회도 읽기 사용량에 영향을 준다. [공식 요금/할당량](https://firebase.google.com/docs/firestore/quotas). Spark 한도에 도달하면 기능이 제한될 수 있다. 결제 수단을 추가하지 않는다.

## 로컬 보안·다중 사용자 검증

JDK 21, Node 22, Flutter, Chromium이 필요하다. CI는 운영 계정 없이 `demo-paylog` Auth/Firestore 에뮬레이터만 사용한다.

```sh
npm ci --prefix scripts/firestore-tests
# Playwright가 설치된 경로를 함께 포함한다.
export NODE_PATH="$PWD/scripts/firestore-tests/node_modules:/path/to/browser-tools/node_modules"
npx --yes firebase-tools@14.22.0 emulators:exec --only firestore --project demo-paylog 'node --test scripts/tests/firestore-rules.test.cjs'
```

전체 브라우저 검증은 `PAYLOG_USE_EMULATORS=true` 빌드를 별도 `build/firebase-emulator`에 만들고 8097 포트로 실행한 뒤 Auth/Firestore 에뮬레이터 안에서 `node scripts/household-emulator-smoke.cjs`를 실행한다. 이 빌드는 운영에 배포하지 않는다. CI의 별도 출력 디렉터리와 기본 false 설정으로 운영 빌드와 구분한다.
