#!/usr/bin/env bash
# The AppImage (with the full Tk launcher) is built by packaging/linux/build.sh; this name is
# kept for older instructions. `nix-build packaging` still gives result/bin/bbport, without the
# launcher and with a bundled Mesa.
set -euo pipefail
exec bash -- "$(dirname -- "$0")/linux/build.sh" "$@"
