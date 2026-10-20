#!/usr/bin/env bash
# Run in the user's own Google Cloud Shell. No credential transfer is needed.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -gt 1 || ($# -eq 1 && "$1" != '--prepare-only' && "$1" != '--resume') ]]; then
  echo 'Usage: bash scripts/deploy-cloud-shell.sh [--prepare-only|--resume]' >&2
  exit 2
fi
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-paylog-c5c2d}"
export GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-438590959896-lv20igk5957lblgjkvl4lo0h0mhch1l6.apps.googleusercontent.com}"
python3 - <<'PY'
import importlib.util, os
spec=importlib.util.spec_from_file_location('deploy','scripts/deploy-hosting.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.settings(os.environ)
PY
node -e 'if (Number(process.versions.node.split(".")[0]) < 20) { console.error("Node.js 20 이상이 필요합니다."); process.exit(1); }'
if [[ "${1:-}" != '--prepare-only' ]]; then
  if [[ -z "${FIREBASE_TOKEN:-}" ]]; then
    npx --yes firebase-tools@14.22.0 login --no-localhost
  fi
  python3 - <<'PYAUTH'
import importlib.util, os
spec=importlib.util.spec_from_file_location('deploy','scripts/deploy-hosting.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
try:
    m.preflight(os.environ)
except RuntimeError as error:
    raise SystemExit(str(error)) from None
PYAUTH
fi
if [[ "${1:-}" != '--resume' ]]; then
# Keep toolchain downloads outside the repository. Never overwrite an existing
# SDK with a different revision.
paylog_sdk="${PAYLOG_FLUTTER_SDK:-${TMPDIR:-/tmp}/paylog-flutter-3.47.7}"
if [[ ! -d "$paylog_sdk" ]]; then
  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$paylog_sdk"
fi
if [[ "$(git -C "$paylog_sdk" rev-parse HEAD)" != 'abaf9c523780a608bd46686fd5e53740a07077f8' ]]; then
  echo 'Flutter SDK revision mismatch; existing SDK was preserved.' >&2
  exit 1
fi
export PATH="$paylog_sdk/bin:$PATH"
flutter config --no-analytics
(
  cd apps/web
  flutter pub get --enforce-lockfile
  flutter build web --release --no-web-resources-cdn "--dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID"
)
fi
if [[ "${1:-}" == '--prepare-only' ]]; then
  echo '배포용 빌드 완료. 인증과 실제 배포는 수행하지 않았습니다.'
  exit 0
fi
python3 - <<'PY'
import importlib.util, json, os, time, urllib.request
spec=importlib.util.spec_from_file_location('deploy','scripts/deploy-hosting.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
try:
    project, client, env=m.preflight(os.environ)
    m.validate_existing_build(m.ROOT,client)
    sites=m.firebase(['hosting:sites:list','--project',project],env)
    if not any(site.get('name','').endswith('/sites/'+project) for site in sites.get('sites',[])):
        m.firebase(['hosting:sites:create',project,'--project',project],env)
    # Explicit site and paths relative to the generated config prevent deploying
    # another default site or resolving the build directory from the wrong root.
    config=json.loads((m.ROOT/'firebase.json').read_text())
    config['hosting']['site']=project
    config['hosting']['public']='web'
    config_path=m.ROOT/'apps/web/build/cloud-shell.firebase.json'
    config_path.write_text(json.dumps(config))
    m.firebase(['deploy','--only','hosting','--project',project,'--config',str(config_path)],env)
    url='https://'+project+'.web.app'
    for attempt in range(6):
        try:
            with urllib.request.urlopen(url,timeout=15) as response:
                if response.status != 200 or 'paylog' not in response.read().decode('utf-8'):
                    raise RuntimeError('Unexpected Hosting response')
            print('배포 및 HTTP 확인 완료: '+url)
            break
        except Exception:
            if attempt == 5:
                raise SystemExit('배포 API는 성공했지만 공개 페이지 확인은 실패했습니다. Firebase Hosting 콘솔을 확인하세요.')
            time.sleep(5)
except RuntimeError as error:
    raise SystemExit(str(error)) from None
PY
