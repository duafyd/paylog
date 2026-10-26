# Firebase 전환 결정

결정일: 2026-10-26 (한국 시간). 사용자가 방향을 확정했다.

## 확정 방향

- 기존 Firebase 프로젝트 `paylog-c5c2d`와 Hosting 주소를 유지한다.
- Google Sheets 원장·공유 ACL·GAS·수동 기기 토큰 설정을 Firebase Authentication과 Cloud Firestore로 대체한다.
- 부부 두 사람이 각자 계정으로 로그인하고 하나의 가족 원장을 사용한다. 초기 멤버 정원은 두 명으로 제한한다.
- Spark 무료 요금제와 결제 수단 등록 없는 운영을 기본 제약으로 한다. 무료 한도는 무제한이 아니며 초과 시 실패/중단을 처리한다. 사용자의 별도 결정 없이 Blaze로 전환하지 않는다.
- Flutter Web·Riverpod와 기존 달력·통계·수동 거래·CSV UI를 재사용한다. 이 문서는 설계 결정이며 전환 완료를 뜻하지 않는다. 현재 배포본은 여전히 Sheets 기반이다.

## 기기 지원

- Galaxy S25: Android Chrome 및 홈 화면 웹앱에서 로그인·조회·입력·동기화를 제공한다. Android 보조 앱의 문자 수집은 별도 개편 대상이다.
- iPhone 16 Pro: Safari 및 홈 화면 웹앱에서 같은 기능과 같은 원장을 제공한다. iPhone에서 임의 SMS를 백그라운드로 읽을 수는 없다. 단축어 전송은 별도 기능으로 재설계·실기기 검증하며 기본 사용은 수동 입력으로 가능하게 한다.
- Google 로그인은 Firebase Auth로 구현하며 Sheets 권한은 요청하지 않는다. Google 브랜드 검증과 Android Play Protect 설치 정책은 별개이므로 DB 전환만으로 자동 해소된다고 보장하지 않는다.

## 무료 운영을 위한 설계

- 가족/월 단위 제한 쿼리와 페이지네이션, 화면 이탈 시 리스너 해제로 읽기량을 제한한다. 전체 거래 상시 구독이나 무한 폴링을 하지 않는다.
- Firebase Auth UID와 가족 멤버십을 기준으로 Security Rules에서 읽기·쓰기 권한을 검증한다. UI 숨김만으로 접근을 제한하지 않는다. 초대 수락·역할 변경·두 명 정원은 원자성 및 규칙 테스트가 필요하다.
- 거래 변경·중복 방지는 Firestore 원자적 쓰기와 결정적인 수집 ID를 사용하도록 설계한다. 서로 다른 정상 결제를 금액만으로 합치지 않는다.
- Cloud Functions, 유료 서버, Storage 첨부파일, 유료 백업/PITR 등은 초기 의존성에 넣지 않는다. 서버 처리가 필요한 기능은 무료 요금제로 가능한지 먼저 검토한다.
- 원문 SMS·사용자 계정·금융 데이터를 분석 이벤트나 로그에 넣지 않는다. 금융 데이터의 브라우저 영구 오프라인 캐시는 기본적으로 사용하지 않는다.

## 구현 순서

1. 모델·저장소 경계와 Security Rules, 멤버 초대 흐름을 설계한다.
2. Firebase Auth와 Firestore 저장소를 구현하고 권한·분리·원자성 검증을 에뮬레이터로 수행한다.
3. 기존 UI를 연결하고 두 기기의 공동 원장 동기화를 검증한다. 실제 기기 검증은 별도 상태로 기록한다.
4. Android 문자 수집의 인증·저장 경로를 개편하고 iPhone 단축어의 가능 범위를 별도로 검증한다.
5. 기존 Sheets 데이터는 필요할 때 사용자가 선택해 이전하며 중복 방지·결과 확인을 제공한다. 이전 확인 전 원본을 삭제하지 않는다.
6. 무료 한도·접근 규칙을 확인한 후 웹과 APK를 배포하고 README·개인정보처리방침·설치 가이드를 갱신한다.

## 1단계 구현: Firebase Auth 웹 연결

웹 앱 `paylog-web` (`1:438590959896:web:618667aa5bf1292a1d6e6d`)의 공개 설정으로 FlutterFire를 연결했다. `/sign-in`에서 SDK 준비 후 Google 팝업 로그인을 제공한다. Sheets 권한은 요청하지 않는다. Firebase SDK는 SESSION 지속성을 사용하고 토큰은 앱 모델/UI에 노출하지 않는다. 계정 UID 변경·로그아웃·인증 스트림 오류 때 이전 원장 캐시를 초기화한다. Sheets 저장 경로는 전환 기간의 이전 방식으로 유지되며 이 로그인만으로 Firestore 저장이나 부부 초대가 구현되는 것은 아니다. 개인정보처리방침에 SDK 세션 저장과 Firebase 계정 처리를 반영했다.

인증 SDK는 로그인 화면 진입 시 준비해 팝업 버튼이 활성화되기 전에 초기화한다. 취소·차단·미승인 도메인·네트워크 오류는 안전한 사용자 문구로 표시하고 원본 예외나 토큰을 출력하지 않는다. 초기화 시간 초과와 늦은 응답도 처리한다. iOS에서 자동 리디렉션으로 우회하지 않으며 사용자의 버튼 동작으로 팝업을 연다. 실제 Safari/홈 화면 팝업·Google 동의·운영 Auth 설정은 사용자 계정으로 별도 검증해야 한다.

### 소유자 운영 확인

Firebase Console에서 Google 제공업체를 켠 다음 Authentication → 설정 → 승인된 도메인에 `paylog-c5c2d.web.app` 및 `paylog-c5c2d.firebaseapp.com`이 있는지 확인한다. 기존 OAuth 웹 클라이언트 원본 목록과 Firebase Auth 승인 도메인은 별도 설정이다. Firebase 웹 앱의 apiKey 등은 공개 연결 식별자이며 서비스 계정 키가 아니다. API 키에 HTTP referrer 제한을 별도로 적용했다면 실제 두 호스트의 로그인 요청도 허용해야 한다. 관리자 비밀키를 웹에 넣지 않는다.

현재 단계의 배포는 웹만 대상으로 한다. 새 브랜치를 내려받아 `bash scripts/deploy-cloud-shell.sh`를 실행한 뒤 홈페이지의 Google 계정으로 시작 → Google로 로그인으로 진행한다. 로그인 후 Authentication → 사용자 목록에 본인 계정이 생기는지 확인한다. 로그아웃·재로그인·새로고침과 각 기기의 팝업을 확인한다. 이 단계의 배포나 테스트를 위해 Firestore 테스트 모드/공개 규칙을 활성화할 필요는 없다. Firestore 생성·보안 규칙·부부 초대·거래 저장은 다음 단계다.

### 자동 검증 방법

`flutter analyze`, `flutter test`, release 빌드를 수행한다. `scripts/firebase-auth-smoke.cjs`는 정적 서버에 열린 release 웹을 대상으로 실제 FlutterFire JS SDK와 명시적으로 모의한 Auth REST 응답을 사용한다. SDK 초기화·상태 전달·탭 세션 새로고침·로그아웃을 검증하고 Sheets 요청이 없는지 확인한다. SDK 모듈은 공식 gstatic HTTPS에서 내려받으며 인증서 검증을 끄지 않는다. 실제 Google 동의/팝업 로그인과 운영 Firebase 권한은 검증하지 않으며 모의 계정을 운영 Firebase에 만들지 않는다.

```sh
python3 -m http.server 8096 --directory apps/web/build/web
# 별도 터미널, Playwright와 Chromium이 있는 환경
PAYLOG_BASE_URL=http://127.0.0.1:8096 node scripts/firebase-auth-smoke.cjs
```
