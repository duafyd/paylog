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
