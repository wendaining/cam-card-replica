#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
faux_cli="${FAUX_CLI:-$HOME/.local/bin/faux}"
faux_app="${FAUX_APP:-$HOME/Applications/FauxCam.app}"
faux_cache="$HOME/Library/Caches/cam-card-replica/fauxcam-downloads"
faux_guest="$faux_cache/libFaux.dylib"
config_file="/tmp/camcard-fauxcam-config.json"
socket_path="/private/tmp/com.fauxcam/camcard-$$.sock"
source_image="${FAUX_SOURCE:-$repo_root/TestData/cards/en-01.png}"
if [[ ! -x "$faux_cli" || ! -f "$faux_app/Contents/Resources/libFaux.dylib" ]]; then
    echo "Install FauxCam.app and the faux CLI, or set FAUX_APP and FAUX_CLI." >&2
    exit 1
fi
if [[ -e "$config_file" ]]; then
    echo "An existing FauxCam test configuration is active: $config_file" >&2
    exit 1
fi
mkdir -p "$faux_cache" TestResults
cp "$faux_app/Contents/Resources/libFaux.dylib" "$faux_guest"
codesign --force --sign - --timestamp=none "$faux_guest"
"$faux_cli" doctor "$faux_guest"
"$faux_cli" serve "$socket_path" --source "image:$source_image" > TestResults/faux-server-latest.log 2>&1 &
server_pid=$!
cleanup() {
    kill -INT "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    rm -f "$config_file"
}
trap cleanup EXIT
for attempt in {1..30}; do
    [[ -S "$socket_path" ]] && break
    sleep 0.1
done
[[ -S "$socket_path" ]]
python3 - "$config_file" "$faux_guest" "$socket_path" <<'PY'
import json,sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({'dylib':sys.argv[2],'socket':sys.argv[3]}))
PY
xcodebuild -project CamCardReplica.xcodeproj -scheme CamCardReplica \
    -destination "${DESTINATION:-platform=iOS Simulator,name=iPhone 18 Pro}" -derivedDataPath build \
    test -enableCodeCoverage NO -only-testing:CamCardReplicaUITests/FauxCameraUITests \
    2>&1 | tee TestResults/faux-camera-latest.log
