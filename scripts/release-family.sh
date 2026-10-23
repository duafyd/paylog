#!/usr/bin/env bash
# Run in the owner's Cloud Shell; credentials and signing keys stay there.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 0 ]]; then
  echo 'Usage: bash scripts/release-family.sh' >&2
  exit 2
fi
# Confirm the APK publishing login before changing either public site.
if ! command -v gh >/dev/null; then
  echo 'GitHub CLI가 필요합니다: sudo apt-get update && sudo apt-get install -y gh' >&2
  exit 1
fi
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo '먼저 실행하세요: gh auth login --hostname github.com --git-protocol https --web' >&2
  exit 1
fi
bash scripts/deploy-cloud-shell.sh
python3 scripts/release-android.py
python3 scripts/verify-release.py --web-build apps/web/build/web
printf '\n가족용 웹·APK 배포와 공개 파일 확인 완료. 가족 계정·SMS 수신은 운영 가이드에 따라 확인하세요.\n'
