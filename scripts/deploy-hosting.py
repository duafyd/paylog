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


def firebase(args, env, *, live=False):
    command = ['npx', '--yes', 'firebase-tools@14.22.0', *args, '--non-interactive']
    if live:
        # Show normal CLI diagnostics directly in the owner's terminal. Never
        # enable debug logging or serialize the environment/credentials.
        result = subprocess.run(command, cwd=ROOT, env=env)
        if result.returncode:
            raise RuntimeError('Firebase 배포가 실패했습니다. 바로 위 Firebase 오류 메시지를 확인하세요. 기존 APK와 서명키는 보존했습니다.')
        return None
    command.append('--json')
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True)
    # Never echo raw CLI responses/errors: they can contain credentials/URLs.
    try:
        payload = json.loads(result.stdout)
    except ValueError:
        raise RuntimeError('Firebase 응답을 확인하지 못했습니다. 인증·네트워크 설정을 확인하세요.') from None
    if result.returncode or payload.get('status') != 'success':
        details = json.dumps(payload).lower() + getattr(result, 'stderr', '').lower()
        operation = args[0]
        if any(word in details for word in ['invalid_grant', 'authentication error', 'unauthenticated', 'invalid token', 'invalid authentication', 'reauthenticate']):
            raise RuntimeError(f'Firebase {operation}: 인증이 만료됐거나 토큰이 잘못됐습니다. unset FIREBASE_TOKEN 후 firebase login --no-localhost --reauth로 다시 로그인하세요.')
        if any(word in details for word in ['permission_denied', 'permission denied', 'does not have permission', 'insufficient permission']):
            raise RuntimeError(f'Firebase {operation}: 현재 계정에 프로젝트 권한이 없습니다. 프로젝트를 만든 Google 계정인지 확인하세요.')
        if any(word in details for word in ['service_disabled', 'has not been used', 'it is disabled']):
            raise RuntimeError(f'Firebase {operation}: 필요한 Google API가 비활성 상태입니다. 프로젝트의 API 설정을 확인하세요.')
        raise RuntimeError(f'Firebase {operation} 요청이 거부됐습니다. Cloud Shell에서 unset FIREBASE_TOKEN 후 npx --yes firebase-tools@14.22.0 projects:list로 오류 원인을 확인하세요.')
    return payload.get('result')


def preflight(environ):
    project, client = settings(environ)
    env = deployment_environment(environ)
    token = env.get('FIREBASE_TOKEN', '').strip()
    if token and (token.startswith('4/') or len(token) < 32):
        raise RuntimeError('FIREBASE_TOKEN에 일회용 인증 코드 또는 올바르지 않은 값이 들어 있습니다. unset FIREBASE_TOKEN 후 firebase login --no-localhost --reauth로 로그인하세요.')
    if not token:
        env.pop('FIREBASE_TOKEN', None)
        accounts = firebase(['login:list'], env)
        if not isinstance(accounts, list) or not accounts or not accounts[0].get('tokens', {}).get('refresh_token'):
            raise RuntimeError('Firebase 인증이 없습니다. 본인 계정으로 firebase login을 완료하거나 FIREBASE_TOKEN을 환경 설정에 안전하게 등록하세요.')
    projects = firebase(['projects:list'], env)
    if not isinstance(projects, list) or not any(p.get('projectId') == project for p in projects):
        raise RuntimeError('인증된 계정에서 지정한 Firebase 프로젝트를 찾지 못했습니다. 프로젝트를 임의로 만들거나 변경하지 않았습니다.')
    return project, client, env


def validate_existing_build(project_root, client):
    """Allow a resumed deployment only for an intact, current production build."""
    build = project_root / 'apps/web/build/web'
    script = build / 'main.dart.js'
    if not all((build / name).is_file() for name in ['index.html', 'main.dart.js', 'manifest.json']):
        raise RuntimeError('완료된 웹 빌드가 없습니다. --resume 없이 다시 실행하세요.')
    if client not in script.read_text():
        raise RuntimeError('기존 빌드의 Google OAuth ID가 다릅니다. --resume 없이 다시 실행하세요.')
    sources = subprocess.run(['git', 'ls-files', 'apps/web/lib', 'apps/web/web', 'apps/web/assets', 'apps/web/pubspec.yaml', 'apps/web/pubspec.lock'], cwd=project_root, text=True, capture_output=True, check=True)
    if any((project_root / name).stat().st_mtime > script.stat().st_mtime for name in sources.stdout.splitlines()):
        raise RuntimeError('웹 소스가 기존 빌드보다 새롭습니다. --resume 없이 다시 빌드하세요.')


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
        firebase(['deploy', '--only', 'firestore:rules', '--project', project, '--config', str(ROOT / 'firebase.json')], env, live=True)
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
