# Android SMS 보조 앱

Galaxy S25 / Android 16을 대상으로 한 Kotlin 앱이다. 새 SMS 수신 → 실제 허용 발신자 선필터 → multipart 본문 결합 → Android Keystore AES/GCM 암호화 대기열 → WorkManager 네트워크 재시도를 구현했다. READ_SMS는 요청하지 않는다. 원문/토큰을 로그에 출력하지 않으며 설정 토큰·큐는 noBackupFilesDir에 암호화 저장한다. WorkManager에는 큐 ID만 전달한다. 클라우드 백업·기기 이전을 제외하고 설정 화면 캡처도 차단한다.

JDK **21**, Android SDK API **36** / Build Tools **36.0.0**, Gradle **8.13**, AGP **8.13.2**, Kotlin **2.2.21**을 사용한다.

```sh
# 저장소 루트, 일반 Android 개발 환경
cd apps/sms_android
./gradlew assembleDebug testDebugUnitTest lintDebug
# Linux x86_64 /workspace 클라우드 환경에서는
cd ../..
bash scripts/bootstrap-android.sh
bash scripts/check-android.sh
```

`app/build/outputs/apk/debug/app-debug.apk`가 개발용 설치 파일이다. 릴리스 서명과 사이트 직접 배포는 아래 안내를 따른다. Play 스토어 배포는 포함하지 않는다. Android Studio에서는 SDK 경로를 본인 local.properties에 설정할 수 있으며 이 파일은 Git에서 제외된다. Gradle 배포 ZIP 체크섬을 고정했다. 일부 SDK 관리 환경에서 platform-tools/라이선스 설정을 요구하면 Android SDK Manager에서 해당 도구를 설치하고 라이선스를 확인한다.

1. `docs/sms-setup.md`에 따라 소유자가 기기 UUID·토큰 해시와 실제 카드/발신번호 매핑을 먼저 등록한다.
2. 앱에 GAS `/exec` URL, 기기 UUID, 원본 토큰, 실제 발신번호(쉼표 구분)를 입력한다. 토큰은 웹앱이나 저장소에 입력하지 않는다.
3. 수집 ON으로 저장하고 SMS 수신 권한을 허용한다. OFF로 저장하면 새 수집/전송을 중지한다. 이미 진행 중인 HTTP 요청은 완료될 수 있다. 즉시 서버 철회가 필요하면 Devices.enabled=false로 설정한다.
4. 대기 전송 재시도/삭제 버튼으로 미전송 항목을 처리한다. 큐는 최대 100건이며 초과 시 신규 SMS가 저장되지 않고 상태에 실패를 표시한다. 각 대기 항목은 최초 큐 UUID를 messageId로 사용하여 네트워크 재시도 시 유지한다.
5. 네트워크 재연결 시 지수 백오프로 재시도한다. 인증/형식 오류는 수동 설정 수정 후 재시도한다. 생성/중복/비허용카드/검토함 응답을 JSON 본문까지 확인한 경우에만 큐에서 삭제한다. GAS 원본 POST 이후 허용된 googleusercontent 응답 위치로만 GET 리다이렉트를 수행한다.
6. 대기 항목이 7일을 초과하면 다음 작업 실행 시 삭제하고 수동 등록 필요 상태를 표시한다. 기기가 계속 오프라인이면 정리 시점도 늦어질 수 있다. 앱 삭제/키 손실 시 복구할 수 없다. 재연결 전에는 기존 기기 토큰을 서버에서 폐기한다.

자동 검증은 APK 빌드·Android Lint·URL/리다이렉트 제한 JVM 테스트다. 수신 권한 허용, 실제 SMS/PDU, 재부팅 후 작업 복구, 삼성 배터리 제한, 암호화 키의 실제 기기 동작은 검증하지 않았다. WorkManager의 즉시 실행을 보장하지 않는다. 화면의 최근 상태는 다시 열 때 갱신된다.

## 릴리스 설치 파일

`1.0.0`부터 실제 배포용 서명키를 지원한다. [릴리스 배포 절차](../../docs/deployment.md)의 `python3 scripts/release-android.py`를 본인 Cloud Shell에서 실행하면 서명 APK를 검증하고 같은 Firebase 프로젝트의 `https://paylog-c5c2d-android.web.app/`에 게시한다. 웹 사이트 업데이트와 별도로 유지되는 다운로드 전용 사이트다. 서명키는 본인 계정에 보관하고 같은 키로 후속 업데이트를 만든다. 암호화된 키 파일의 백업과 본인 암호 보관이 필요하다. APK와 공개 체크섬만 게시하며 키·암호를 업로드하지 않는다.

새 디버그 빌드는 `app.paylog.sms.debug`, 릴리스는 `app.paylog.sms`다. 기존 0.1.0 디버그 APK는 릴리스와 패키지가 같고 서명이 달라 직접 업데이트할 수 없으므로, 설정/대기 문자를 확인한 뒤 기존 개발용 앱을 삭제하고 릴리스를 설치해야 한다. 실제 SMS·삼성 배터리 제한 검증 상태는 기존과 동일하게 미검증이다.
