#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../apps/web"
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
