#!/usr/bin/env bash
set -euo pipefail
# Linux x86_64 cloud setup, isolated from system directories. Downloads are pinned.
python3 - <<'PY'
import pathlib,urllib.request,hashlib,zipfile,tarfile,os
base=pathlib.Path('/workspace/tools');base.mkdir(parents=True,exist_ok=True)
cache=base/'android-downloads';cache.mkdir(exist_ok=True)
sdk=base/'android-sdk';sdk.mkdir(exist_ok=True)
def fetch(name,url,sha):
    path=cache/name
    if not path.exists(): urllib.request.urlretrieve(url,path)
    if hashlib.sha256(path.read_bytes()).hexdigest()!=sha: raise RuntimeError('Checksum mismatch: '+name)
    return path
if not (base/'jdk-21.0.12.1+1/bin/javac').exists():
    name='OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz'
    path=fetch(name,'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/'+name,'ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94')
    with tarfile.open(path) as archive: archive.extractall(base,filter='data')
for name,sha,dest,folder in [
 ('platform-36_r02.zip','37607369a28c5b640b3a7998868d45898ebcb777565a0e85f9acf36f29631d2e','platforms','android-36'),
 ('build-tools_r36_linux.zip','5d9ac77fb6ff43d9da518a337b4fcf8f9097113df531d99ccefe80ef7ce8250b','build-tools','36.0.0')]:
    root=sdk/dest;root.mkdir(exist_ok=True)
    if not (root/folder).exists():
        path=fetch(name,'https://dl.google.com/android/repository/'+name,sha)
        with zipfile.ZipFile(path) as archive: archive.extractall(root)
        if (root/'android-16').exists(): (root/'android-16').rename(root/folder)
for file in (sdk/'build-tools/36.0.0').iterdir():
    if file.is_file() and file.suffix not in ['.jar','.txt','.properties']: file.chmod(0o755)
if not (base/'gradle-8.13/bin/gradle').exists():
    path=fetch('gradle-8.13-bin.zip','https://services.gradle.org/distributions/gradle-8.13-bin.zip','20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78')
    with zipfile.ZipFile(path) as archive: archive.extractall(base)
(base/'gradle-8.13/bin/gradle').chmod(0o755)
print('Verified JDK 21, Android API 36/build tools 36.0.0, Gradle 8.13')
PY
