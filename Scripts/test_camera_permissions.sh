#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
config_file=/tmp/camcard-system-camera-config.json
if [[ -e "$config_file" ]]; then
    echo "A system-camera test configuration is already active." >&2
    exit 1
fi
simulator="${SIMULATOR:-iPhone 18 Pro}"
bundle_id=com.wendaining.CamCardReplica
cleanup() {
    rm -f "$config_file"
    xcrun simctl privacy "$simulator" grant camera "$bundle_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT
mkdir -p TestResults
for scenario in authorized denied prompt-allow prompt-deny; do
    case "$scenario" in
        authorized) action=grant ;;
        denied) action=revoke ;;
        prompt-*) action=reset ;;
    esac
    xcrun simctl privacy "$simulator" "$action" camera "$bundle_id"
    python3 - "$config_file" "$scenario" <<'PY'
import json,sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({'expected':sys.argv[2]}))
PY
    xcodebuild -project CamCardReplica.xcodeproj -scheme CamCardReplica \
        -destination "${DESTINATION:-platform=iOS Simulator,name=iPhone 18 Pro}" -derivedDataPath build \
        test -enableCodeCoverage NO -only-testing:CamCardReplicaUITests/SystemCameraPermissionUITests \
        2>&1 | tee "TestResults/system-camera-$scenario.log"
done
