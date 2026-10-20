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

## 프로젝트 목록 조회에서 인증 오류가 날 때

`Built build/web` 뒤 `projects:list`에서 실패하면 아직 Hosting 배포는 실행되지 않았다. `FIREBASE_TOKEN`에 일회용 인증 코드·예시 문자열·만료된 값이 들어 있으면 CLI 로그인보다 우선되어 정상 계정 접근을 막을 수 있다. Cloud Shell에서 다음 순서로 복구한다.

```sh
unset FIREBASE_TOKEN
npx --yes firebase-tools@14.22.0 login --no-localhost --reauth
# 프로젝트를 만든 계정으로 로그인 완료 후, 기존 저장소 폴더에서
# git pull --ff-only가 성공한 경우에만 수정된 배포 스크립트를 실행
if git pull --ff-only; then
  bash scripts/deploy-cloud-shell.sh --resume
fi
```

`--resume`은 성공한 기존 빌드의 필수 파일·OAuth ID·빌드 이후 웹 소스 변경 여부를 확인하고 다운로드/재빌드를 생략한다. 소스가 바뀌었거나 빌드가 없으면 일반 실행으로 다시 빌드해야 한다. 인증과 프로젝트 접근은 이제 SDK 설치·빌드보다 먼저 확인한다. 인증/권한/API 비활성 오류는 민감한 원문을 출력하지 않고 원인별 안내를 제공한다. 여전히 프로젝트 접근이 안 되면 같은 계정에서 `npx --yes firebase-tools@14.22.0 projects:list`를 직접 실행해 오류 안내를 확인한다. 코드는 Cloud Shell에만 입력하고 채팅에는 보내지 않는다.

## Android 릴리스 APK 배포 (본인 Cloud Shell)

릴리스는 `app.paylog.sms`, versionName `1.0.0`, versionCode `2`다. 이후 디버그 빌드는 `.debug` 패키지와 개발용 앱 이름을 사용한다. CI에는 실배포 키를 넣지 않으며, CI의 unsigned 릴리스 APK는 설치·배포용으로 사용하지 않는다.

이미 웹 배포에 성공한 **동일한 Cloud Shell의 paylog 폴더**에서 다음을 실행한다. 현재 계정의 Firebase 프로젝트 접근을 먼저 확인한다.

```sh
git pull --ff-only && python3 scripts/release-android.py
```

처음 실행할 때 **앱 서명키 전용 새 암호**를 두 번 입력한다(영문·숫자·기호 12자 이상). Google 로그인 코드나 Google 계정 비밀번호를 입력하는 단계가 아니다. 개인 암호 관리자에 암호를 보관하고 채팅에 보내지 않는다. 키는 본인의 Cloud Shell 홈 `~/.local/share/paylog-signing/paylog-release.p12`에 생성하고 다음 빌드에도 재사용한다. 키와 암호 파일이 일부만 남아 있으면 새 키로 덮어쓰지 않고 중단한다.

Cloud Shell에 처음 키를 생성하면 `cloudshell download`로 **본인 암호로 암호화된 PKCS12 키 파일**의 개인 백업 다운로드를 요청한다. 이 파일과 암호를 안전하게 보관해야 다음 버전을 같은 앱으로 업데이트할 수 있다. 서명키·암호는 Git, 공개 Hosting, Actions artifact에 업로드하지 않는다. Cloud Shell 저장소만을 영구 백업으로 간주하지 않는다. 암호 파일은 키와 함께 Cloud Shell의 개인 디렉터리에만 두며 권한은 600이다.

스크립트는 고정 JDK/Android SDK/Gradle 설치, 릴리스 단위 테스트·Lint·APK 빌드, APK 서명과 보관 키의 공개 인증서 일치, 패키지·버전·debuggable=false를 확인한다. 같은 Firebase 프로젝트의 다운로드 전용 Hosting 사이트에 APK와 다운로드 페이지를 배포한다. 웹 가계부의 사이트·데이터는 변경하지 않는다. 업로드된 APK를 HTTPS로 다시 받아 SHA-256도 확인한다.

- 다운로드 페이지: `https://paylog-c5c2d-android.web.app/`
- 설치 파일: `https://paylog-c5c2d-android.web.app/paylog-sms.apk`
- 공개 무결성 정보: `/android-release.json`, `/paylog-sms.apk.sha256`

위 주소는 **릴리스 스크립트가 실제로 성공한 뒤** 사용할 수 있다. 릴리스 서명이 실제 SMS 수신·백그라운드 동작 검증을 대신하지 않는다. GAS·기기 등록이 필요하고 실기기 검증은 이번 요청에서 제외돼 있다. 기존 0.1.0 개발용 APK가 설치돼 있으면 서명이 달라 교체 설치가 필요할 수 있다. 개발용 앱 삭제 전 설정과 대기 문자를 확인한다. 삭제 시 해당 앱의 개인 저장소는 사라진다.

다른 Firebase 프로젝트는 FIREBASE_PROJECT_ID / GOOGLE_WEB_CLIENT_ID, 다른 SDK 위치는 PAYLOG_TOOLS_DIR, 다운로드 사이트 ID는 PAYLOG_ANDROID_SITE_ID로 지정한다. `--build-only`는 공개 배포 없이 서명 APK까지만 만든다. Play 스토어 등록·심사·SMS 권한 승인은 이 직접 APK 배포에 포함하지 않는다.

### APK 빌드 성공 후 Hosting 배포만 실패한 경우

프로젝트·사이트 조회가 성공해도 실제 업로드 권한이나 배포 설정 오류는 별도로 발생할 수 있다. 일반적인 로그인 오류로 단정하지 않는다. 최신 스크립트는 배포 시 Firebase CLI의 일반 오류 출력을 본인 터미널에 그대로 표시한다(`--debug` 사용 안 함).

```sh
cd "$HOME/paylog"
git pull --ff-only
unset FIREBASE_TOKEN
python3 scripts/release-android.py --resume
```

`--resume`은 기존 APK 존재·소스 수정 시각·기존 키 파일을 확인하고 Gradle 빌드를 건너뛴다. APK 서명·보관 키 인증서 일치·버전·debuggable 검사는 다시 수행한다. 기존 키를 재생성하지 않으며, 새 소스가 있거나 APK가 없으면 일반 빌드를 요구한다. 배포 실패 후 임시 게시 폴더는 정리되므로 이전 Firebase config를 직접 재사용하지 말고 이 명령으로 다시 구성한다. 오류를 공유할 때 토큰·인증 코드·서명키 암호는 포함하지 않는다.
