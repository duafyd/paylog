#!/usr/bin/env python3
"""Read-only verification of public family web/APK releases; never logs credentials."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('android_release', ROOT / 'scripts/release-android.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def fetch(url):
    request = urllib.request.Request(url, headers={'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(request, timeout=40) as response:
        data = response.read(64 * 1024 * 1024 + 1)
        if response.status != 200 or len(data) > 64 * 1024 * 1024:
            raise RuntimeError('공개 파일 응답 또는 크기가 올바르지 않습니다.')
        return data


def verify_web(base, build=None, get=fetch):
    index = get(base + '/').decode('utf-8')
    if 'flutter_bootstrap.js' not in index:
        raise RuntimeError('웹앱 시작 페이지가 올바르지 않습니다.')
    documents = {'privacy.html': '개인정보처리방침', 'terms.html': '서비스 이용약관'}
    for name, title in documents.items():
        content = get(base + '/' + name)
        text = content.decode('utf-8')
        if '<h1>' + title + '</h1>' not in text or 'flutter_bootstrap.js' in text or 'mailto:duafyd@gmail.com' not in text:
            raise RuntimeError(name + ': 실제 정책 문서가 아닙니다. 최신 웹을 다시 배포하세요.')
        if build is not None and content != (build / name).read_bytes():
            raise RuntimeError(name + ': 배포된 문서가 로컬 빌드와 다릅니다.')
    manifest = json.loads(get(base + '/manifest.json'))
    if manifest.get('display') != 'standalone' or not manifest.get('icons'):
        raise RuntimeError('홈 화면 설치용 manifest가 올바르지 않습니다.')
    if build is not None:
        for name in ['index.html', 'main.dart.js', 'flutter_bootstrap.js', 'manifest.json', 'legal.css']:
            if hashlib.sha256(get(base + '/' + name)).digest() != hashlib.sha256((build / name).read_bytes()).digest():
                raise RuntimeError(name + ': 배포 파일과 로컬 빌드의 해시가 다릅니다.')


def verify_android(base, get=fetch):
    metadata = json.loads(get(base + '/android-release.json'))
    if metadata.get('versionName') != release.VERSION or metadata.get('versionCode') != release.VERSION_CODE:
        raise RuntimeError('공개 APK가 최신 버전 ' + release.VERSION + '이 아닙니다.')
    if metadata.get('url') != release.APK_URL:
        raise RuntimeError('APK 다운로드 주소가 이번 릴리스의 GitHub 주소와 다릅니다.')
    for key in ['sha256', 'certificateSha256']:
        if not re.fullmatch(r'[a-f0-9]{64}', str(metadata.get(key, ''))):
            raise RuntimeError('APK 공개 해시 또는 인증서 정보가 올바르지 않습니다.')
    apk = get(release.APK_URL)
    if not apk.startswith(b'PK') or len(apk) != metadata.get('size') or hashlib.sha256(apk).hexdigest() != metadata['sha256']:
        raise RuntimeError('실제 APK 파일이 공개 무결성 정보와 다릅니다.')
    # Signing verification is performed against the owner's key before upload
    # by release-android.py. This check only verifies public distribution bytes.
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--web-only', action='store_true')
    parser.add_argument('--web-build', type=Path, help='배포에 실제로 사용한 로컬 빌드 디렉터리')
    args = parser.parse_args()
    project = os.environ.get('FIREBASE_PROJECT_ID', 'paylog-c5c2d')
    site = os.environ.get('PAYLOG_ANDROID_SITE_ID', project + '-android')
    if not all(re.fullmatch(r'[a-z0-9][a-z0-9-]{0,28}[a-z0-9]', value) for value in [project, site]):
        print('프로젝트/사이트 ID 형식을 확인하세요.', file=sys.stderr)
        return 1
    failures = []
    checks = [('웹·정책 문서', lambda: verify_web('https://' + project + '.web.app', args.web_build))]
    if not args.web_only:
        checks.append(('APK ' + release.VERSION, lambda: verify_android('https://' + site + '.web.app')))
    for label, check in checks:
        try:
            check()
            print('PASS · ' + label)
        except (RuntimeError, OSError, ValueError, KeyError) as error:
            message = str(error) if isinstance(error, RuntimeError) else '공개 응답 또는 로컬 파일을 확인하지 못했습니다.'
            failures.append(label)
            print('FAIL · ' + label + ' · ' + message, file=sys.stderr)
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
