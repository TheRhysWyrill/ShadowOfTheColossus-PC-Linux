#!/usr/bin/env bash
# Builds dist/SotC-x86_64.AppImage from the Linux build (run `bash build.sh` in the repo root
# first). The Tk launcher is frozen with PyInstaller, so players need no Python; the libraries
# the game and the GPU library load come along, except the ones that must come from the host
# (glibc, Vulkan loader and drivers, X11/Wayland, fonts, audio).
# Needs: ldd, objdump/strip (binutils), curl (appimagetool), Python with PyInstaller and Pillow,
# tkinter, a C compiler with static libc. Release builds: .github/workflows/linux-appimage.yml
# (Ubuntu 24.04, packaging/linux/ci-deps.sh).
set -euo pipefail
cd -- "$(dirname -- "$0")/../.."
[[ -f out/bb-probe && -f out/gpu/libbbgpu.so ]] || { echo 'Build first: bash build.sh' >&2; exit 1; }

appdir=out/AppDir
rm -rf "$appdir"
share=$appdir/usr/share/sotc
mkdir -p "$share/bin/gpu" "$appdir/usr/lib"

install -m755 out/bb-probe out/bb-gpu-capabilities "$share/bin/"
install -m755 out/gpu/libbbgpu.so "$share/bin/gpu/"
cp sotc.py LICENSE README.md CHANGELOG.md docs/sotc/README-SotC.md "$share/"
install -m644 packaging/linux/README-Linux.txt "$share/"
# Settings and key bindings start here and the launcher copies them to the data folder (the mount
# is read-only): the same names as on Windows, with POSIX examples. The launcher fills in the game
# folder it finds, so SOTC_GAME_DIR stays commented out.
cat > "$share/sotc.ini" <<'EOF'
# Shadow of the Colossus PC - settings (see README-Linux.txt)
# Folder of your game dump (the one with eboot.bin): CUSA08809 (EU) or CUSA08034 (US).
# SOTC_GAME_DIR=/path/to/CUSA08809
# Folder with libSceNgs2.sprx and libSceUlt.sprx from YOUR OWN console (for sound):
# SOTC_SYS_MODULES=/path/to/sys_modules
# Optional modes: af16 (sharp textures), fps60 (no 30 FPS cap, experimental):
# SOTC_MODES=af16
EOF
cp -r scripts "$share/"
mkdir -p "$share/launcher"
install -m644 launcher/sotc.png launcher/window_icon.png "$share/launcher/"
# Xbox-style button icons drawn for the port (tools/make_button_icons.py), when they were built.
[[ -d glyphs ]] && cp -r glyphs "$share/"

# The launcher also runs sotc.py (--run) and the preparation scripts (--script) itself, as on
# Windows: the standard modules those scripts import come along as hidden imports.
hidden=()
for module in argparse base64 collections hashlib json pathlib re shutil struct; do
    hidden+=(--hidden-import "$module")
done
python3 -m PyInstaller --version >/dev/null 2>&1 || {
    echo 'Need PyInstaller: pip install pyinstaller pillow' >&2
    exit 1
}
python3 -m PyInstaller --noconfirm --clean --log-level WARN --windowed --name sotc-launcher \
    --distpath out/pyi-dist --workpath out/pyi-work --specpath out/pyi-work \
    --paths "$PWD/scripts" "${hidden[@]}" "$PWD/launcher/sotc_launcher_win.py"
cp -r out/pyi-dist/sotc-launcher/. "$share/"
find "$share" -name __pycache__ -prune -exec rm -r {} +

# AppRun is static: Steam starts non-Steam games with its overlay in LD_PRELOAD, which the
# AppImage's glibc cannot load. The static program clears that environment, then runs the script
# that sets the data folder and the bundled libraries and starts the launcher.
cc=${CC:-cc}
"$cc" -O2 -Wall -Wextra -Werror -static -DTARGET='"AppRun.sh"' packaging/bbport-entry.c \
    -o "$appdir/AppRun" || {
    echo 'Building the static AppRun failed: install a C compiler and the static libc (build-essential)' >&2
    exit 1
}
install -m755 packaging/linux/AppRun.sh "$appdir/AppRun.sh"
install -m644 packaging/linux/sotc.desktop "$appdir/sotc.desktop"
install -m644 launcher/sotc.png "$appdir/sotc.png"

# No game files and nothing a player made may ship (the same rule as the Windows package).
# (The packaged sotc.ini is the blank template above, not a player's.)
forbidden=$(find "$appdir" \( -iname eboot.bin -o -iname sce_module -o -iname sce_sys -o -iname savedata \
    -o -iname user -o -iname cache -o -iname '*.log' -o -iname sotc.ini -o -iname launcher_settings.json \
    -o -iname '*.sprx' -o -iname '*.prx' -o -iname '*.pkg' \) -print | grep -vx "$share/sotc.ini" || true)
if [[ -n $forbidden ]]; then
    echo 'The AppImage holds files that must not ship:' >&2
    echo "$forbidden" >&2
    exit 1
fi

# Host-provided libraries: bundling any of these breaks drivers, input or the display connection.
excluded='^(ld-linux.*|libc|libm|libdl|librt|libpthread|libresolv|libutil|libnsl|libanl|libvulkan|libGL|libGLX|libGLdispatch|libEGL|libOpenGL|libgbm|libdrm.*|libX11|libX11-xcb|libxcb.*|libXau|libXdmcp|libXext|libXfixes|libXrender|libXi|libXcursor|libXrandr|libXft|libXss|libXtst|libXinerama|libwayland-.*|libasound|libudev|libpulse.*|libfontconfig|libfreetype|libOpenCL|libva.*|libvdpau|libvpl|libnvidia-.*|libcuda|libz|libstdc\+\+|libgcc_s)\.so'
declare -A seen
seen[libbbgpu.so]=1  # it stays next to the probe, in bin/gpu ($ORIGIN/gpu)
bundle() {
    local elf=$1 line lib name
    while read -r line; do
        lib=$(awk '/=> \//{print $3}' <<<"$line")
        [[ -n $lib ]] || continue
        name=$(basename -- "$lib")
        [[ ${seen[$name]:-} ]] && continue
        seen[$name]=1
        [[ $name =~ $excluded ]] && continue
        install -m755 "$lib" "$appdir/usr/lib/$name"
        bundle "$lib"
    done < <(ldd "$elf")
}
bundle out/bb-probe
bundle out/bb-gpu-capabilities
bundle out/gpu/libbbgpu.so
# libstdc++/libgcc come from the build host: the same glibc generation as the one that runs the
# AppImage is assumed, and a newer libstdc++ than the host's is the safe direction.
for name in libstdc++.so.6 libgcc_s.so.1; do
    install -m755 "$(ldd out/bb-probe | awk -v n="$name" '$1==n{print $3}')" "$appdir/usr/lib/$name"
done
# $ORIGIN/gpu is already the probe's RUNPATH; the rest sits in usr/lib via AppRun.
find "$appdir/usr/lib" -name '*.so*' -exec strip --strip-unneeded {} + 2>/dev/null || true

# The newest glibc symbol in the bundle is the oldest glibc players can have. Built on a rolling
# distro it follows the host's and the AppImage stops starting on SteamOS, Debian and Fedora:
# release builds come from .github/workflows/linux-appimage.yml (Ubuntu 24.04). SOTC_MAX_GLIBC
# raises the limit for local builds.
max_glibc=${SOTC_MAX_GLIBC:-2.39}
need=$(find "$appdir" -type f \( -name '*.so*' -o -perm -u+x \) -exec objdump -T {} + 2>/dev/null |
       grep -o 'GLIBC_2\.[0-9.]*' | sed 's/GLIBC_//' | sort -uV | tail -1 || true)  # objdump fails on scripts
if [[ -z $need ]]; then
    echo 'Could not read the bundled glibc version (objdump).' >&2
    exit 1
fi
if [[ $(printf '%s\n' "$need" "$max_glibc" | sort -V | tail -1) != "$max_glibc" ]]; then
    echo "The bundle needs glibc $need, newer than $max_glibc: build on Ubuntu 24.04 (packaging/linux/ci-deps.sh) or set SOTC_MAX_GLIBC" >&2
    exit 1
fi
echo "Minimum glibc: $need"

tool=${APPIMAGETOOL:-$(command -v appimagetool || true)}
if [[ -z $tool ]]; then
    tool=out/appimagetool-x86_64.AppImage
    [[ -x $tool ]] || {
        curl -fL -o "$tool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
        chmod +x "$tool"
    }
fi
mkdir -p dist
# Written aside and moved over: replacing a running AppImage in place fails ("Text file busy").
ARCH=x86_64 "$tool" --appimage-extract-and-run "$appdir" dist/SotC-x86_64.AppImage.new
mv -f dist/SotC-x86_64.AppImage.new dist/SotC-x86_64.AppImage
ls -lh dist/SotC-x86_64.AppImage
