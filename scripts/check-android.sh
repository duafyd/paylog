#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - "$@" <<'PY'
import os,subprocess,sys,pathlib,urllib.parse
base=pathlib.Path('/workspace/tools')
env=dict(os.environ)
if (base/'jdk-21.0.12.1+1').exists(): env.setdefault('JAVA_HOME',str(base/'jdk-21.0.12.1+1'))
env.setdefault('ANDROID_HOME',str(base/'android-sdk'))
env.setdefault('ANDROID_USER_HOME','/workspace/.android')
env.setdefault('GRADLE_USER_HOME','/workspace/.gradle')
pathlib.Path(env['ANDROID_USER_HOME']).mkdir(parents=True,exist_ok=True)
gradle=str(base/'gradle-8.13/bin/gradle') if (base/'gradle-8.13/bin/gradle').exists() else 'gradle'
args=[gradle,'-p','apps/sms_android',*(sys.argv[1:] or ['assembleDebug','testDebugUnitTest','lintDebug']),'--no-daemon','--max-workers=4']
proxy=urllib.parse.urlsplit(env.get('HTTPS_PROXY',''))
if proxy.hostname and not proxy.username:
    for protocol in ['http','https']: args += [f'-D{protocol}.proxyHost={proxy.hostname}',f'-D{protocol}.proxyPort={proxy.port or 8080}']
# Use the installed system trust store, including the environment's trusted
# network proxy CA. Certificate validation remains enabled.
trust=pathlib.Path('/etc/ssl/certs/java/cacerts')
if trust.exists(): args += ['-Djavax.net.ssl.trustStore='+str(trust)]
sys.exit(subprocess.run(args,env=env).returncode)
PY
