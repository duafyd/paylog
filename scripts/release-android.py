#!/usr/bin/env python3
"""Build with the owner's persistent Android key and publish APK via Hosting."""
import argparse
import getpass
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
VERSION = '1.0.2'
VERSION_CODE = 4
ALIAS = 'paylog-release'
REPOSITORY = 'duafyd/paylog'
RELEASE_TAG = 'android-v' + VERSION
APK_URL = f'https://github.com/{REPOSITORY}/releases/download/{RELEASE_TAG}/paylog-sms.apk'
spec = importlib.util.spec_from_file_location('hosting', ROOT / 'scripts/deploy-hosting.py')
hosting = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hosting)


def signing_material(directory, keytool, prompt=getpass.getpass):
    if directory.resolve().is_relative_to(ROOT):
        raise RuntimeError('서명키는 저장소 밖의 개인 디렉터리에 보관해야 합니다.')
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    directory.chmod(0o700)
    store, password_file = directory / 'paylog-release.p12', directory / 'signing.keypass'
    if store.exists() != password_file.exists():
        raise RuntimeError('서명키 또는 암호 파일이 누락됐습니다. 새 키를 만들지 말고 기존 백업을 복원하세요.')
    if not store.exists():
        print('업데이트에 계속 사용할 앱 서명키를 생성합니다. 암호는 본인이 보관하고 채팅에 보내지 마세요.')
        password = prompt('서명키 전용 새 암호 (영문·숫자·기호 12자 이상, 입력은 숨겨짐): ')
        if len(password) < 12 or not password.isascii() or any(c in password for c in '\r\n'):
            raise RuntimeError('서명키 암호는 영문·숫자·기호로 12자 이상이어야 합니다.')
        if prompt('암호 다시 입력: ') != password:
            raise RuntimeError('암호가 일치하지 않습니다. 키를 생성하지 않았습니다.')
        descriptor = os.open(password_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(password)
        try:
            result = subprocess.run([str(keytool), '-genkeypair', '-noprompt', '-keystore', str(store), '-storetype', 'PKCS12', '-storepass:file', str(password_file), '-alias', ALIAS, '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000', '-dname', 'CN=paylog Android Release,O=paylog,C=KR'], capture_output=True, text=True)
            if result.returncode:
                raise RuntimeError('서명키 생성에 실패했습니다. 백업/파일 상태를 확인하세요.')
        except Exception:
            # Do not silently replace or delete a potentially created identity.
            if not store.exists():
                password_file.unlink()
            raise
    store.chmod(0o600)
    password_file.chmod(0o600)
    return store, password_file


def stage_download(apk, public, metadata):
    if apk.name.endswith('-unsigned.apk'):
        raise RuntimeError('서명되지 않은 APK는 배포할 수 없습니다.')
    download = public / 'downloads'
    download.mkdir(parents=True, exist_ok=True)
    data = apk.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    certificate = metadata.get('certificateSha256', '')
    if not re.fullmatch(r'[a-f0-9]{64}', certificate):
        raise RuntimeError('검증된 공개 서명 인증서 지문이 필요합니다.')
    metadata = {'certificateSha256': certificate, 'versionName': VERSION, 'versionCode': VERSION_CODE, 'sha256': digest, 'size': len(data), 'url': APK_URL}
    (download / 'paylog-sms.apk').write_bytes(data)
    (download / 'paylog-sms.apk.sha256').write_text(digest + '  paylog-sms.apk\n')
    (download / 'android-release.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2))
    (download / 'index.html').write_text('''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>paylog Android 앱</title><style>body{background:#f7f8fa;color:#263735;font:16px system-ui;margin:0;padding:32px 20px}main{max-width:520px;margin:32px auto;background:white;border-radius:24px;padding:28px}a{display:block;background:#207a75;color:white;padding:18px;text-align:center;border-radius:16px;text-decoration:none}p{line-height:1.7}small{color:#526562}</style><main><h1>paylog Android</h1><p>문자를 받아 우리 집 가계부로 전송하는 보조 앱입니다.</p><a href="''' + APK_URL + '''">Android 앱 다운로드 · v''' + VERSION + '''</a><p>다운로드한 APK를 열어 설치하세요. 설치를 요청한 브라우저의 ‘알 수 없는 앱 설치’ 허용이 필요할 수 있습니다.</p><p>SMS 자동 수집에는 GAS 주소·기기 등록·SMS 수신 권한 설정이 필요합니다.</p><small>이전 개발용 앱은 서명이 달라 교체 설치가 필요할 수 있습니다. 삭제하면 그 앱의 설정과 대기 문자가 삭제됩니다. 실제 SMS 수신·배터리 제한 동작은 기기에서 확인해야 합니다.</small></main></html>''')
    return metadata


def hosting_config(site):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,28}[a-z0-9]', site):
        raise RuntimeError('다운로드 사이트 ID 형식이 올바르지 않습니다. PAYLOG_ANDROID_SITE_ID를 확인하세요.')
    return {'hosting': {'site': site, 'ignore': ['**/.*', '**/*.apk'],
        'redirects': [{'source': '/paylog-sms.apk', 'destination': APK_URL, 'type': 302}],
        'headers': [
        {'source': '**', 'headers': [
            {'key': 'X-Content-Type-Options', 'value': 'nosniff'},
            {'key': 'Cache-Control', 'value': 'no-cache'}]},
        {'source': '/paylog-sms.apk', 'headers': [
            {'key': 'Content-Type', 'value': 'application/vnd.android.package-archive'},
            {'key': 'Content-Disposition', 'value': 'attachment; filename="paylog-sms.apk"'}]},
    ]}}


def publish_github(download, metadata):
    """Publish only verified public artifacts; never replace a published release."""
    base = ['gh', 'release']
    view = subprocess.run([*base, 'view', RELEASE_TAG, '--repo', REPOSITORY,
                           '--json', 'isDraft'], text=True, capture_output=True)
    if view.returncode:
        commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT,
                                text=True, capture_output=True, check=True).stdout.strip()
        subprocess.run([*base, 'create', RELEASE_TAG, '--repo', REPOSITORY,
                        '--target', commit, '--draft', '--title', 'paylog Android ' + VERSION,
                        '--notes', 'Signed Android SMS companion. See the in-app guide for setup. Physical-device SMS testing is pending.'], check=True)
    elif not json.loads(view.stdout)['isDraft']:
        existing = subprocess.run([*base, 'download', RELEASE_TAG, '--repo', REPOSITORY,
                                   '--pattern', 'android-release.json', '--output', '-'],
                                  text=True, capture_output=True, check=True)
        previous = json.loads(existing.stdout)
        if any(previous.get(key) != metadata[key] for key in ['sha256', 'certificateSha256', 'versionCode']):
            raise RuntimeError('이 버전은 다른 APK로 이미 공개됐습니다. 기존 파일을 교체하지 말고 버전을 올려 주세요.')
        return
    subprocess.run([*base, 'upload', RELEASE_TAG, '--repo', REPOSITORY, '--clobber',
                    *[str(download / name) for name in
                      ['paylog-sms.apk', 'paylog-sms.apk.sha256', 'android-release.json']]], check=True)
    subprocess.run([*base, 'edit', RELEASE_TAG, '--repo', REPOSITORY,
                    '--draft=false', '--latest=false'], check=True)


def gradle_environment(tools, store, password_file):
    env = dict(os.environ)
    env['JAVA_HOME'] = str(tools / 'jdk-21.0.12.1+1')
    env['ANDROID_HOME'] = str(tools / 'android-sdk')
    env['PAYLOG_RELEASE_STORE_FILE'] = str(store)
    env['PAYLOG_RELEASE_STORE_PASSWORD'] = password_file.read_text().rstrip('\r\n')
    env['PAYLOG_RELEASE_KEY_PASSWORD'] = env['PAYLOG_RELEASE_STORE_PASSWORD']
    env['PAYLOG_RELEASE_KEY_ALIAS'] = ALIAS
    return env


def validate_existing_apk(root):
    apk = root / 'apps/sms_android/app/build/outputs/apk/release/app-release.apk'
    if not apk.is_file():
        raise RuntimeError('기존 서명 APK가 없습니다. --resume 없이 실행하세요.')
    sources = subprocess.run(
        ['git', 'ls-files', 'apps/sms_android/app/src',
         'apps/sms_android/app/build.gradle.kts', 'apps/sms_android/build.gradle.kts',
         'apps/sms_android/settings.gradle.kts', 'apps/sms_android/gradle.properties',
         'apps/sms_android/gradle'], cwd=root, text=True, capture_output=True, check=True)
    if any((root / name).stat().st_mtime > apk.stat().st_mtime
           for name in sources.stdout.splitlines()):
        raise RuntimeError('Android 소스가 기존 APK보다 새롭습니다. --resume 없이 다시 빌드하세요.')
    return apk


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-only', action='store_true', help='서명 APK 검증까지만 진행하고 배포하지 않음')
    parser.add_argument('--resume', action='store_true', help='기존 APK의 서명·버전·소스 상태를 확인하고 빌드 없이 배포 재시도')
    options = parser.parse_args()
    tools = Path(os.environ.get('PAYLOG_TOOLS_DIR', '/tmp/paylog-android-tools')).resolve()
    keydir = Path(os.environ.get('PAYLOG_SIGNING_DIR', str(Path.home() / '.local/share/paylog-signing'))).resolve()
    os.environ.setdefault('FIREBASE_PROJECT_ID', 'paylog-c5c2d')
    os.environ.setdefault('GOOGLE_WEB_CLIENT_ID', '438590959896-lv20igk5957lblgjkvl4lo0h0mhch1l6.apps.googleusercontent.com')
    try:
        # Confirm account/project before generating a production signing identity.
        if not options.build_only:
            project, client, firebase_env = hosting.preflight(os.environ)
            if not shutil.which('gh'):
                raise RuntimeError('GitHub CLI가 필요합니다. Cloud Shell에서 sudo apt-get update && sudo apt-get install -y gh 를 실행하세요.')
            if subprocess.run(['gh', 'auth', 'status', '--hostname', 'github.com'], capture_output=True).returncode:
                raise RuntimeError('GitHub 로그인이 필요합니다. gh auth login --hostname github.com --git-protocol https --web 실행 후 재시도하세요.')
        if options.resume:
            validate_existing_apk(ROOT)
            if not all((keydir / name).is_file() for name in ['paylog-release.p12', 'signing.keypass']):
                raise RuntimeError('기존 서명키와 암호 파일을 먼저 복원하세요. 재개 시 새 키를 만들지 않습니다.')
        subprocess.run(['bash', str(ROOT / 'scripts/bootstrap-android.sh')], env={**os.environ, 'PAYLOG_TOOLS_DIR': str(tools)}, check=True)
        keytool = tools / 'jdk-21.0.12.1+1/bin/keytool'
        first_key = not (keydir / 'paylog-release.p12').exists()
        store, password_file = signing_material(keydir, keytool)
        if first_key and shutil.which('cloudshell'):
            print('본인 암호로 암호화된 서명키 백업 다운로드를 요청합니다. 안전한 개인 저장소에 보관하세요.')
            subprocess.run(['cloudshell', 'download', str(store)], check=True)
        env = gradle_environment(tools, store, password_file)
        args = [str(tools / 'gradle-8.13/bin/gradle'), '-p', str(ROOT / 'apps/sms_android'), 'testReleaseUnitTest', 'lintRelease', 'assembleRelease', '--no-daemon', '--max-workers=4']
        proxy = urllib.parse.urlsplit(env.get('HTTPS_PROXY', ''))
        if proxy.hostname and not proxy.username:
            for protocol in ['http', 'https']:
                args += [f'-D{protocol}.proxyHost={proxy.hostname}', f'-D{protocol}.proxyPort={proxy.port or 8080}']
        trust = Path('/etc/ssl/certs/java/cacerts')
        if trust.exists():
            args += ['-Djavax.net.ssl.trustStore=' + str(trust)]
        if not options.resume:
            subprocess.run(args, env=env, check=True)
        apk = ROOT / 'apps/sms_android/app/build/outputs/apk/release/app-release.apk'
        signer = tools / 'android-sdk/build-tools/36.0.0/apksigner'
        verify = subprocess.run([str(signer), 'verify', '--verbose', '--print-certs', str(apk)], env=env, text=True, capture_output=True, check=True)
        fingerprint = re.search(r'Signer #1 certificate SHA-256 digest: ([a-fA-F0-9]+)', verify.stdout)
        if not fingerprint:
            raise RuntimeError('APK 서명 인증서 지문을 확인하지 못했습니다.')
        cert = subprocess.run([str(keytool), '-exportcert', '-alias', ALIAS, '-keystore', str(store), '-storepass:file', str(password_file)], capture_output=True, check=True).stdout
        if hashlib.sha256(cert).hexdigest() != fingerprint[1].lower():
            raise RuntimeError('APK와 보관된 서명키의 인증서가 다릅니다. 배포를 중단했습니다.')
        badging = subprocess.run([str(tools / 'android-sdk/build-tools/36.0.0/aapt2'), 'dump', 'badging', str(apk)], env=env, text=True, capture_output=True, check=True).stdout
        if not re.search(rf"package: name='app.paylog.sms' versionCode='{VERSION_CODE}' versionName='{re.escape(VERSION)}'", badging) or 'application-debuggable' in badging:
            raise RuntimeError('APK의 버전·패키지 또는 디버그 설정이 릴리스 조건과 다릅니다.')
        if options.build_only:
            print('릴리스 서명 및 인증서 일치 확인 완료: ' + str(apk))
            return 0
        site = os.environ.get('PAYLOG_ANDROID_SITE_ID', project + '-android')
        config = hosting_config(site)
        sites = hosting.firebase(['hosting:sites:list', '--project', project], firebase_env)
        if not any(s.get('name', '').endswith('/sites/' + site) for s in sites.get('sites', [])):
            hosting.firebase(['hosting:sites:create', site, '--project', project], firebase_env)
        build = ROOT / 'apps/sms_android/app/build'
        # A dedicated site and a fresh public directory keep the web app intact
        # and make it impossible for a signing file to enter the upload tree.
        with tempfile.TemporaryDirectory(prefix='android-release-public-', dir=build) as public_dir:
            metadata = stage_download(apk, Path(public_dir), {'certificateSha256': fingerprint[1].lower()})
            download = Path(public_dir) / 'downloads'
            publish_github(download, metadata)
            # Spark Hosting rejects APK files. Keep only HTML and public metadata.
            (download / 'paylog-sms.apk').unlink()
            config['hosting']['public'] = str(Path(public_dir).relative_to(build) / 'downloads')
            config_path = build / 'android-release.firebase.json'
            config_path.write_text(json.dumps(config))
            hosting.firebase(['deploy', '--only', 'hosting', '--project', project, '--config', str(config_path)], firebase_env, live=True)
        url = APK_URL
        with urllib.request.urlopen(url, timeout=30) as response:
            if hashlib.sha256(response.read()).hexdigest() != metadata['sha256']:
                raise RuntimeError('배포된 APK 해시가 일치하지 않습니다.')
        print('정식 서명 APK 배포·해시 확인 완료: ' + url)
        print('다운로드 페이지: https://' + site + '.web.app/')
        print('업데이트용 서명키(본인 암호로 암호화됨)를 안전하게 백업하세요: ' + str(store))
        print('Cloud Shell에서 백업 다운로드: cloudshell download ' + str(store))
        print('서명키 암호도 본인 암호 관리자에 보관하세요. 키나 암호를 채팅/Git에 올리지 마세요.')
        return 0
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(str(error) if isinstance(error, RuntimeError) else '릴리스 빌드 또는 배포에 실패했습니다. 위 단계와 로컬 빌드 보고서를 확인하세요.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
