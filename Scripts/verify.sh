#!/usr/bin/env bash
# Local equivalent of CI: what `make verify` runs, with nicer output.
set -euo pipefail
cd "$(dirname "$0")/.."

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone Duo}"

echo "==> swiftformat (lint)"
swiftformat --lint Sources Tests UITests

echo "==> swiftlint"
swiftlint --quiet || true

echo "==> build"
xcodebuild -project CamCardReplica.xcodeproj -scheme CamCardReplica \
  -destination "$DESTINATION" -derivedDataPath build build | tail -3

echo "==> unit + integration tests"
xcodebuild -project CamCardReplica.xcodeproj -scheme CamCardReplica \
  -destination "$DESTINATION" -derivedDataPath build test \
  -only-testing:CamCardReplicaTests | grep -E "Executed .* tests|TEST" | tail -5

echo "==> OK"
