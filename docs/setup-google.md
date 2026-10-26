# Google 로그인·Sheets 연결 PoC

> 이 문서는 이전 Sheets 연결 경로입니다. 새 Firebase 로그인 설정과 검증은 [Firebase 전환 문서](FIREBASE_MIGRATION.md)를 따릅니다. 새 로그인은 Sheets 권한을 요청하지 않습니다.

이 단계는 Google Identity Services(GIS) 웹 토큰 모델로 계정을 확인하고 Sheets REST API 접근을 검증한다. **아래 접근 확인 PoC와 별도로 [Sheets 원장 연결](sheets-ledger.md)이 추가되었다.** 기존 시트는 GET으로만 검사한다. 쓰기 검증은 사용자가 명시적으로 요청한 새 테스트 시트에서만 수행한다.

## 1. Google Cloud에서 직접 설정

1. Google Cloud Console에서 본인 프로젝트를 생성하거나 선택한다.
2. API 및 서비스에서 **Google Sheets API**를 활성화한다. 이 PoC는 Drive API, Firebase Auth, 서비스 계정 키를 사용하지 않는다.
3. Google Auth Platform에서 앱 이름·지원 이메일·대상 사용자를 설정한다. 외부 앱을 테스트 모드로 운영하면 실제 검증에 사용할 가족 계정을 테스트 사용자로 추가한다.
4. 데이터 액세스 범위는 `openid`, `email`, `profile`과 `https://www.googleapis.com/auth/spreadsheets`다. 앱에서는 먼저 계정 확인 범위를 요청하고, 별도 버튼으로 Sheets 동의를 요청한다. Sheets 범위는 특정 파일 하나만으로 제한되지 않으며 민감 범위 검증·테스트 모드 제한을 Google Console에서 확인해야 한다.
5. OAuth 클라이언트를 **웹 애플리케이션**으로 생성한다. 승인된 JavaScript 원본에 실제 실행할 `scheme://host:port`를 정확히 등록한다. 경로와 와일드카드를 넣지 않는다. 로컬 개발은 아래 예시를 사용하고 실제 배포 도메인도 별도로 추가한다.

```text
http://localhost:8080
http://127.0.0.1:8080
https://YOUR_DEPLOYMENT_HOST
```

6. 발급된 **클라이언트 ID**를 로컬 환경 또는 클라우드 환경 설정의 `GOOGLE_WEB_CLIENT_ID`에 넣는다. 웹 클라이언트 ID는 공개 식별자다. **클라이언트 비밀키, 서비스 계정 JSON, 사용자 액세스 토큰은 입력하지 않는다.** 플랫폼의 `GOOGLE_APPLICATION_CREDENTIALS`는 브라우저 사용자 OAuth를 대체하지 않는다.

클라우드 네트워크 설정에는 기존 목록을 유지하면서 `accounts.google.com`, `openidconnect.googleapis.com`, `sheets.googleapis.com`, `oauth2.googleapis.com`, `www.gstatic.com` 접근이 필요하다. 공식 문서 조회는 `developers.google.com`을 사용한다. 실제 배포 브라우저의 DNS/방화벽/팝업 차단도 별도로 확인한다.

## 2. 실행과 화면 순서

환경 변수는 실행 중 Flutter 웹 번들에서 직접 읽을 수 없으므로 **빌드/실행 시 dart-define에 전달**해야 한다. 환경 설정에 값을 넣은 뒤 앱을 다시 빌드한다.

```sh
# 클라우드에서 먼저: source /workspace/tools/flutter-env.sh
cd apps/web
flutter pub get --enforce-lockfile
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID"
# 배포용
flutter build web --release --no-web-resources-cdn \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID"
```

설정 → **Google 연결 검증 열기** → Google 로그인 → **같은 계정으로** Sheets 권한 요청 순서로 진행한다. 로그인 모듈을 먼저 로드한 후 버튼을 활성화하고, 사용자 클릭에서 GIS 팝업을 직접 연다. 토큰 만료 시 사용자 버튼으로 다시 동의한다.

- **기존 시트 읽기 확인:** 본인이 접근 가능한 시트 ID 또는 Google Sheets URL을 입력한다. `Transactions` 탭의 A:R 헤더가 원본 명세와 정확히 일치해야 하며, 일치하면 제목·데이터 행 수만 표시한다. 행 내용은 화면에 노출하지 않고 기존 데이터를 변경하지 않는다. 이 PoC의 행 수는 거래 집계가 아니다.
- **전용 테스트 시트 생성·쓰기 확인:** 확인창에 동의하면 본인 Drive에 `paylog 연결 테스트` 스프레드시트를 생성한다. Asia/Seoul 시트 시간대, 명세의 Transactions 헤더, 1,000원 가상 거래 1건을 RAW로 저장하고 UUID·금액을 다시 읽어 검증한다. 생성한 URL을 복사해 직접 확인한다. 자동 삭제하지 않으므로 테스트 후 Drive에서 직접 삭제한다.
- **실패 후 처리:** 생성까지 성공했으면 후속 쓰기·읽기에 실패해도 생성 ID를 화면에 남긴다. 네트워크 실패 후 POST를 자동 재시도하지 않는다. 먼저 해당 시트를 확인한다. 다시 '생성'을 누르면 별도 시트가 추가된다.
- **연결 해제:** 메모리의 계정·토큰·시트 정보부터 지우고 Google 권한 철회를 요청한다. 철회 실패 시 Google 계정의 연결된 앱에서 수동으로 확인한다. Google 계정 자체에서 로그아웃시키는 동작은 아니다.

## 3. 보안·권한 경계

토큰은 메모리에만 보관한다. localStorage/sessionStorage/파일/Git에 쓰지 않으며 토큰·Google 오류 본문을 로그 또는 UI에 출력하지 않는다. 프로필은 Google userinfo HTTPS 응답으로 확인하고, Sheets 동의 계정의 subject가 로그인 계정과 일치하는지 검사한다. 사용자 입력으로 API 호스트를 바꾸지 못하게 고정 Google 호스트만 허용한다.

Apps Script 범용 API, `no-cors`, 고정 비밀키는 사용하지 않는다. `Members.role`은 권한 증거가 아니며 접근 권한은 실제 Google Sheets 공유 ACL이다. 이 PoC는 Members 스키마·가족 참여·Viewer의 실제 쓰기 거부를 검증하는 완성 원장이 아니다. 테스트 시트 행의 memberId/updatedBy는 검증 계정 subject를 임시로 사용하며, 이후 Members UUID 매핑 어댑터에 그대로 가져오지 않는다.

## 4. 자동 검증 (모의 응답)

```sh
cd apps/web
flutter analyze
flutter test
# 모의 GIS/API 브라우저 테스트 전용 번들. 실제 계정 검증에 사용하지 않는다.
flutter build web --release --no-web-resources-cdn \
  --dart-define=GOOGLE_WEB_CLIENT_ID=browser-test.apps.googleusercontent.com \
  --output=build/google-poc
python3 -m http.server 8081 --bind 127.0.0.1 --directory build/google-poc
```

다른 터미널에서 저장소 루트 기준:

```sh
npm install --prefix /tmp/paylog-browser-tools --no-save playwright@1.62.1
NODE_PATH=/tmp/paylog-browser-tools/node_modules CHROMIUM_PATH=/usr/bin/chromium \
  node scripts/google-connection-smoke.cjs
```

이 브라우저 테스트는 GIS 스크립트와 Google API 응답을 Playwright로 가로채는 **모의 검증**이다. 실제 OAuth/계정 권한/CORS/Google 서비스 정상 여부를 입증하지 않는다. 실제 클라이언트 ID나 토큰을 테스트 코드에 넣지 않는다.

## 5. 반드시 남겨야 할 실제 검증

- [ ] 공개 웹 클라이언트 ID·승인 원본·테스트 사용자 설정 완료.
- [ ] Galaxy S25 Chrome, iPhone 16 Pro Safari, 각각의 홈 화면 PWA에서 계정 선택·권한 거부·팝업 닫기·재동의.
- [ ] 새 시트 생성 → RAW 쓰기 → 재조회 → Drive에서 직접 내용 확인.
- [ ] 가족 계정 공유 시트 읽기 성공, 공유받지 않은 다른 가족 시트 접근 거부.
- [ ] Viewer 읽기 성공; 쓰기 거부는 후속 실제 원장 어댑터에서 별도 검증.
- [ ] Google 공유 해제 및 토큰 만료 후 재접근 거부, 팝업 실패 시 Safari 사용 대안.

실제 검증이 끝난 뒤 Sheets Repository, Members UUID 매핑, 원장 전환, 수정·소프트 삭제·충돌/재시도 처리를 구현한다.

참고: [GIS 토큰 모델](https://developers.google.com/identity/oauth2/web/guides/use-token-model), [GIS JS 레퍼런스](https://developers.google.com/identity/oauth2/web/reference/js-reference), [Sheets API](https://developers.google.com/sheets/api/reference/rest).


## 6. 원장 연동 단계 추가

별도의 **달력에 실제 원장 연결** 패널에서 새 Transactions·Members 템플릿을 만들거나 지원 스키마의 시트를 연결할 수 있다. 연결 후 달력·등록·통계가 해당 원장으로 전환된다. 기본 샘플과 거래를 합치지 않는다. 실제 Google 계정 검증 미실행 상태는 여전히 유효하며 세부 제약은 [원장 가이드](sheets-ledger.md)를 따른다.

## 브랜딩의 앱 도메인·공개 문서

최신 웹을 배포한 뒤 아래 주소를 로그인하지 않은 브라우저에서 확인하고 Google Auth Platform → 브랜딩에 입력한다.

| 항목 | 주소 |
|---|---|
| 애플리케이션 홈페이지 | `https://paylog-c5c2d.web.app` |
| 애플리케이션 개인정보처리방침 링크 | `https://paylog-c5c2d.web.app/privacy.html` |
| 애플리케이션 서비스 약관 링크 | `https://paylog-c5c2d.web.app/terms.html` |

두 문서는 Flutter 실행·Google 로그인 없이 열리는 HTML이다. 앱 설정과 초기 HTML에도 링크가 있다. 개인정보 문의처는 운영자가 지정한 `duafyd@gmail.com`이며, GitHub Issues는 일반 오류 문의용으로 구분한다. 비밀번호·인증 코드·기기 토큰은 이메일로도 보내지 않도록 안내한다. 문서는 실제 데이터 처리 방식·운영 정보가 변경될 때 함께 관리해야 한다.

Cloud Shell의 저장소 루트에서 `git pull --ff-only && bash scripts/deploy-cloud-shell.sh`로 웹만 재배포한다. 페이지 생성·배포가 Google OAuth 검증 승인이나 게시 상태 변경을 자동으로 수행하지는 않는다. 홈페이지 도메인 소유권, 개발자 연락처, 요청 범위와 검증 항목은 Google Console의 실제 요구사항을 따른다.


### Search Console 추가 확인 태그

홈페이지 `<head>`에 HTML 인증 메타태그와 GA4 `G-9FWZ8L9KE5`의 Google 태그를 포함한다. 소유권 확인을 위한 설치이며 `ga-disable-G-9FWZ8L9KE5=true`를 gtag 로드 전에 설정해 분석 이벤트 수집을 비활성화한다. 자동 페이지뷰·Google signals·광고 개인화도 끈다. 외부 스크립트 다운로드 요청은 발생할 수 있으므로 개인정보처리방침에 이를 고지한다. 분석을 활성화하려면 별도 데이터 처리 검토가 필요하다.

소유자가 웹 배포 후 같은 Google 계정의 Search Console → 소유권 인증 → Google 애널리틱스 → 확인을 실행한다. 해당 GA 속성의 수정 권한이 필요하다. 코드 설치 검증은 실제 Search Console 승인이나 OAuth 브랜딩 오류 해소를 보장하지 않는다. 기존 HTML 파일/메타태그 인증은 유지한다.


### Google 태그 관리자 추가 확인

컨테이너 `GTM-KQQ9XCLC`의 제공된 스니펫을 홈페이지 `<head>`에 삽입하고 `<body>` 바로 뒤에 noscript iframe을 둔다. GA4 수집 비활성화 설정은 GTM 로드보다 먼저 유지한다. 앱은 GTM dataLayer에 거래·문자·계정·토큰 정보를 추가하지 않는다. 컨테이너에 분석/광고 태그를 새로 게시하는 작업은 이 변경에 포함하지 않는다.

소유자는 웹 배포 후 같은 Google 계정으로 Search Console → 소유권 인증 → Google 태그 관리자 → 확인을 실행한다. 해당 컨테이너에 게시 권한이 필요하며, 웹 소스 변경과 GTM 작업공간 게시는 서로 다른 작업이다. 스니펫 설치는 Search Console 인증 또는 OAuth 브랜딩 통과를 보장하지 않는다. Google이 별도 게시 상태 문제를 표시하면 그 오류를 확인하고 대응한다.
