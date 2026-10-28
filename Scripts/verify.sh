#!/usr/bin/env bash
# Keep this entry point identical to the documented build gate.
set -euo pipefail
cd "$(dirname "$0")/.."
exec make verify "$@"
