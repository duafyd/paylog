#!/usr/bin/env python3
"""Check the explicitly selected Firebase project, then build/deploy Hosting."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def settings(environ):
    project = environ.get('FIREBASE_PROJECT_ID', '')
    client = environ.get('GOOGLE_WEB_CLIENT_ID', '')
    errors = []
    if not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', project):
        errors.append('FIREBASE_PROJECT_ID: 배포할 실제 Firebase 프로젝트 ID가 필요합니다.')
    if not re.fullmatch(r'[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com', client):
        errors.append('GOOGLE_WEB_CLIENT_ID: 실제 공개 웹 OAuth 클라이언트 ID가 필요합니다.')
    if errors:
        raise RuntimeError('\n'.join(errors))
    return project, client


def deployment_environment(environ):
    env = dict(environ)
    # Platform ADC is unrelated to the user's Firebase account. Require an
    # explicit Firebase CLI login or the user's secure FIREBASE_TOKEN binding.
    env.pop('GOOGLE_APPLICATION_CREDENTIALS', None)
    env.pop('GOOGLE_CLOUD_QUOTA_PROJECT', None)
    env.setdefault('npm_config_cache', '/workspace/.npm' if Path('/workspace').exists() else str(Path.home() / '.npm'))
    return env


def firebase(args, env):
    command = ['npx', '--yes', 'firebase-tools@14.22.0', *args, '--non-interactive', '--json']
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True)
    # Never echo raw CLI responses/errors: they can contain credentials/URLs.
    try:
        payload = json.loads(result.stdout)
    except ValueError:
        raise RuntimeError('Firebase 응답을 확인하지 못했습니다. 인증·네트워크 설정을 확인하세요.') from None
    if result.returncode or payload.get('status') != 'success':
        raise RuntimeError('Firebase 요청이 거부됐습니다. 로그인·프로젝트 권한·네트워크 설정을 확인하세요.')
    return payload.get('result')


def preflight(environ):
    project, client = settings(environ)
    env = deployment_environment(environ)
    if not env.get('FIREBASE_TOKEN'):
        accounts = firebase(['login:list'], env)
        if not isinstance(accounts, list) or not accounts or not accounts[0].get('tokens', {}).get('refresh_token'):
            raise RuntimeError('Firebase 인증이 없습니다. 본인 계정으로 firebase login을 완료하거나 FIREBASE_TOKEN을 환경 설정에 안전하게 등록하세요.')
    projects = firebase(['projects:list'], env)
    if not isinstance(projects, list) or not any(p.get('projectId') == project for p in projects):
        raise RuntimeError('인증된 계정에서 지정한 Firebase 프로젝트를 찾지 못했습니다. 프로젝트를 임의로 만들거나 변경하지 않았습니다.')
    return project, client, env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deploy', action='store_true', help='사전 확인 후 릴리스 빌드와 실제 Hosting 배포')
    options = parser.parse_args()
    try:
        project, client, env = preflight(os.environ)
        print('Firebase 대상·계정 접근 확인 완료. Google 승인 원본에는 https://' + project + '.web.app 을 등록하세요.')
        if not options.deploy:
            print('사전 확인만 수행했습니다. 배포하지 않았습니다.')
            return 0
        subprocess.run(['flutter', 'pub', 'get', '--enforce-lockfile'], cwd=ROOT / 'apps/web', env=env, check=True)
        subprocess.run(['flutter', 'build', 'web', '--release', '--no-web-resources-cdn', '--dart-define=GOOGLE_WEB_CLIENT_ID=' + client], cwd=ROOT / 'apps/web', env=env, check=True)
        firebase(['deploy', '--only', 'hosting', '--project', project, '--config', str(ROOT / 'firebase.json')], env)
        print('Hosting 배포 완료: https://' + project + '.web.app')
        print('실제 OAuth 로그인·공유 ACL·GAS 동작 검증은 배포 완료와 별도로 수행해야 합니다.')
        return 0
    except (RuntimeError, FileNotFoundError, subprocess.CalledProcessError) as error:
        message = str(error) if isinstance(error, RuntimeError) else '필수 도구 또는 빌드 실행에 실패했습니다.'
        print(message, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
