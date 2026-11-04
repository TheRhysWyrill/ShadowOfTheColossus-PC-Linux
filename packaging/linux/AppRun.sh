#!/usr/bin/env bash
# AppImage entry point: starts the frozen Tk launcher. The launcher picks the game folder, runs
# sotc.py (game image preparation + game) and handles --play (the game without the window, for
# shortcuts and Steam).
# Usage: SotC-x86_64.AppImage [--play]
set -euo pipefail
here=$(dirname -- "$(readlink -f -- "$0")")
share=$here/usr/share/sotc

export LD_LIBRARY_PATH="$here/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# The AppImage is a read-only mount: what the port writes (prepared image, saves, shader cache,
# logs, sotc.ini) lives in the user's data folder. SOTC_DATA_DIR moves it.
export SOTC_DATA_DIR=${SOTC_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sotc}
mkdir -p "$SOTC_DATA_DIR"

cd -- "$share"
exec "$share/sotc-launcher" "$@"
