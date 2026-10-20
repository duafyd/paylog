# 배포와 CI

Firebase Hosting 설정은 저장소의 `firebase.json`이다. 실제 배포는 프로젝트 ID와 본인 Firebase 로그인/CI 인증이 있어야 한다. 이 환경에는 `FIREBASE_PROJECT_ID`와 웹 OAuth ID가 없어 실제 배포·운영 OAuth 검증을 수행하지 않았다. 플랫폼 제공 서비스 계정 자격증명을 사용자 계정 대신 사용하지 않는다.

```sh
# Flutter SDK를 PATH에 추가한 뒤
cd apps/web
flutter pub get --enforce-lockfile
flutter build web --release --no-web-resources-cdn \
  --dart-define=GOOGLE_WEB_CLIENT_ID=본인의공개웹클라이언트ID
cd ../..
# Node 22 이상, 본인 Firebase 프로젝트/계정 사용
npx firebase-tools@14.22.0 login
npx firebase-tools@14.22.0 emulators:start --only hosting --project 본인프로젝트ID
npx firebase-tools@14.22.0 deploy --only hosting --project 본인프로젝트ID
```

Hosting SPA rewrite, HTTPS 보안 헤더, JS 재검증과 HTML no-store를 설정했다. OAuth 팝업을 차단할 수 있는 COOP 격리는 적용하지 않았다. GIS·CanvasKit/WebAssembly·인라인 Flutter 부트스트랩을 고려한 CSP는 실제 서비스 도메인과 로그인 동작을 관찰한 뒤 적용한다. 금융 기록/토큰을 서비스워커·로컬 스토리지에 캐시하지 않는다. 현재 PWA는 온라인 실행 기준이다. 홈 화면 설치 절차는 README를 따른다.

Google OAuth의 승인된 JavaScript 원본에 실제 Hosting 도메인을 등록하고 API 활성화·동의 화면·테스트 사용자/공개 정책을 확인한다. OAuth 검증이나 Workspace 정책상 사용이 차단되면 본인 테스트 사용자로 제한하거나 대체 백엔드를 검토한다.

`.github/workflows/verify.yml`은 Flutter 정적 분석·위젯/단위 테스트·웹 빌드, SMS 파서 테스트·GAS 생성물 일치, Android JVM 테스트·Lint·debug APK 빌드를 실행하고 산출물을 보관한다. 자동 배포는 설정하지 않았다. workflow는 PR 제출만으로 성공한 것으로 간주하지 않으며 GitHub 실행 결과를 확인한다. Android APK는 개발용 서명이며 앱스토어 배포물이 아니다.

## 배포 사전 확인과 실행

`scripts/deploy-hosting.py`는 배포 대상과 인증을 먼저 확인한다. 기본 실행은 조회만 하며, `--deploy`를 붙이면 승인된 배포 요청에 따라 실제 Hosting 배포를 수행한다. 실제 OAuth ID가 없는 샘플 빌드는 배포하지 않는다. 플랫폼의 `GOOGLE_APPLICATION_CREDENTIALS`는 자식 프로세스에서 제거하며 사용자 Firebase CLI 로그인 또는 명시적인 Firebase 토큰만 사용한다. 대상 프로젝트가 사용자 계정 목록에서 확인되어야 빌드·배포를 진행한다.

```sh
# 공개 설정값은 본인 Google/Firebase 콘솔에서 확인
export FIREBASE_PROJECT_ID=본인프로젝트ID
export GOOGLE_WEB_CLIENT_ID=본인의공개웹클라이언트ID
# 본인 계정의 firebase login을 완료한 개발 머신에서 실행
python3 scripts/deploy-hosting.py
python3 scripts/deploy-hosting.py --deploy
```

이 클라우드에는 현재 두 공개 ID와 Firebase 로그인 계정이 없다. 클라우드에서 계속 진행하려면 환경 설정의 공개 변수 두 개와 사용자 본인의 Firebase 인증을 연결해야 한다. CLI 로그인을 쓸 수 없으면 신뢰하는 로컬 머신에서 `firebase login:ci`로 얻은 값을 **환경 설정의 FIREBASE_TOKEN 비밀값**에만 등록한다. 채팅·커밋·명령 인자에 토큰을 넣지 않는다. 이 방식은 고정한 Firebase CLI 14.22.0에서 지원되지만 폐기 예정 방식이므로 장기 자동 배포는 사용자 소유 서비스 계정의 Workload Identity Federation을 권장한다. 이 작업에서 사용자를 대신해 서비스 계정이나 유료 프로젝트를 만들지 않았다.

GAS는 별도 소유자 계정의 Apps Script 프로젝트와 가계부 시트가 필요하다. 아직 실제 스크립트 ID·배포 URL이 없으며 [SMS 운영 설정](sms-setup.md)의 순서대로 연결해야 한다. Firebase Hosting 배포가 GAS 배포를 대신하지 않는다. 실제 Google OAuth 승인 원본에는 배포 후의 정확한 웹 도메인을 등록한다.

사전 확인 테스트: `python3 -m unittest discover -s scripts/tests -v`. 샘플/누락 ID 차단, 플랫폼 ADC 및 불완전 CLI 세션의 대체 인증 차단, 사용자 프로젝트 접근 확인, 오류의 비밀값 비노출을 검증한다.

## PC 없이 Google Cloud Shell에서 배포

Codex의 환경 설정 화면에 접근하기 어렵다면 사용자 Google Cloud Shell 안에서 로그인·빌드·배포를 모두 수행한다. 비밀 토큰을 Codex나 채팅으로 옮기지 않는다. 저장소는 공개 상태이므로 GitHub 로그인 없이 소스를 받을 수 있다.

[프로젝트 Cloud Shell 열기](https://shell.cloud.google.com/?project=paylog-c5c2d)에서 아래 명령을 실행한다. 기존 폴더를 덮어쓰지 않도록 새 임시 디렉터리를 사용한다.

```sh
paylog_deploy_dir=$(mktemp -d)
git clone --depth 1 --branch feat/complete-budget-workflows https://github.com/duafyd/paylog.git "$paylog_deploy_dir/paylog"
cd "$paylog_deploy_dir/paylog"
bash scripts/deploy-cloud-shell.sh
```

스크립트는 사용자에게 받은 공개 프로젝트/OAuth ID를 기본값으로 사용하고 Flutter 3.47.7의 커밋을 검증한 뒤 릴리스 빌드를 만든다. SDK가 없으면 임시 도구 디렉터리에 설치한다. `firebase login --no-localhost`의 로그인 링크를 열고 요구하는 코드는 **Cloud Shell 터미널에** 입력한다. 배포 대상 프로젝트 접근을 확인한 뒤 Hosting만 배포하고 공개 HTTP 응답을 확인한다. 토큰을 채팅으로 보내거나 별도 Codex 환경 변수에 등록할 필요가 없다. Google OAuth 승인 원본과 Sheets API 활성화는 Google 콘솔에서 별도로 확인한다.

기본값을 바꾸려면 FIREBASE_PROJECT_ID와 GOOGLE_WEB_CLIENT_ID를 명시적으로 설정한다. `--prepare-only`는 인증/배포 없이 SDK·의존성·실제 OAuth ID의 릴리스 빌드까지만 검증한다. 실제 Cloud Shell 인증/배포는 사용자의 로그인 없이는 이 개발환경에서 대신 검증할 수 없다.

이미 `login:ci`로 토큰을 발급받았다면 Cloud Shell에서 `read -rsp 'Firebase token: ' FIREBASE_TOKEN; export FIREBASE_TOKEN; echo` 한 줄을 실행한 뒤, 숨김 입력에 발급된 토큰을 붙여넣는다. 토큰을 명령문에 직접 넣지 않아 셸 기록에 남기지 않는다. 그다음 위 배포 명령을 실행하면 추가 로그인 없이 해당 인증으로 배포한다. 스크립트는 프로젝트 ID와 같은 Hosting 사이트가 없으면 생성하고 그 사이트를 명시적으로 대상으로 삼는다. 기존 가계부 시트·GAS는 변경하지 않는다.
