Shadow of the Colossus — PC (native port) · Linux AppImage
==========================================================

The PS4 game's own x86-64 code runs directly on your CPU; a Vulkan video core translates the
PS4 GPU. Not an emulator. Bring your own game dump.

This package contains no game files and no Sony firmware.


Requirements
------------
- A 64-bit Linux with glibc 2.39 or newer: SteamOS 3.7+, Bazzite/Fedora 42+, Debian 13+,
  Ubuntu 24.04+ or any newer distribution.
- A Vulkan 1.3 graphics card (NVIDIA, AMD or Intel) with a recent driver.
- The game dump: CUSA08809 (EU 1.01) or CUSA08034 (US 1.00), the folder with eboot.bin,
  sce_module and sce_sys. An SSD is strongly recommended: new areas stream hundreds of MB and
  stutter far more on a hard disk.
- For sound: libSceNgs2.sprx and libSceUlt.sprx from YOUR OWN console, decrypted. They are Sony
  firmware and are never distributed with the port. The launcher finds them in a shadPS4
  installation (~/.local/share/shadPS4/user/sys_modules) and copies them to the port's folder.
  Without them the game runs, silently.


Running
-------
  chmod +x SotC-x86_64.AppImage
  ./SotC-x86_64.AppImage

or double-click the file (your file manager may ask once to trust it).

The AppImage needs FUSE. Without it (some minimal systems), run:
  ./SotC-x86_64.AppImage --appimage-extract-and-run

The first start opens the launcher, which looks for the game folder, the sound modules, a
shadPS4 save (it offers to import it) and the game's DLCs. Check "Game & saves", then click
PLAY. The game image is prepared once (a few seconds) and again only when the game or the
scripts change.

--play starts the game with the last launcher settings, without the window: use it in Steam
and in shortcuts.

  ./SotC-x86_64.AppImage --play


Where things are kept
---------------------
The AppImage is read-only. Everything the port writes goes to:

  ${XDG_DATA_HOME:-~/.local/share}/sotc

  user/savedata/1/CUSA08809|CUSA08034   saves
  user/last_run.log                     the last session's output (the 4 before it too)
  user/events.log                       what happened in the session (crashes included)
  user/crashes/                         copies of the logs of sessions that ended badly
  user/launcher_settings.json           the launcher's options
  user/cache/, user/shader/             shader and pipeline caches (safe to delete)
  out/                                  the prepared game image
  sotc.ini                              settings and key bindings (BB_CONFIG)

SOTC_DATA_DIR=/some/folder moves all of it. SOTC_GAME_DIR, SOTC_SYS_MODULES and the other
names of sotc.py's docstring also work as environment variables; the launcher shows them in
"Advanced > Extra variables".


Steam and the desktop
---------------------
Add the AppImage as a non-Steam game and set its launch options to --play: Steam then starts
the game directly, with its overlay and controller support. The launcher's "Advanced" page has
buttons for a desktop shortcut (the launcher, or the game directly) and for opening the port's
and the data folders.

In the game: F1 / Insert / L3+R3 opens the in-game menu (FPS, upscaler, textures, effects);
F7 switches the 30 FPS cap; F8 frame generation (Windows only); F10 performance overlay;
F11 window/fullscreen. The launcher's "Controls" page remaps keys and buttons.


Graphics
--------
The game renders at 1080p (or the PS4 Pro sizes in PS4 Pro mode) and the image is enlarged to
the chosen output with FSR 1 + RCAS, or bilinear. 720p renders at 1080p, as on PS4. Output
sizes above 16:9 (21:9, 32:9) show more at the sides.

DLSS and frame generation are not available in the Linux build: both need NVIDIA's Streamline
SDK, which is Windows-only. The Windows package has them.


Updates
-------
The launcher checks the project's releases at startup (and on "Check for updates") and shows
the release notes. On Linux it opens the release page: download the new AppImage and replace
the file. Saves, settings and shader caches stay in the data folder above, so nothing is lost.


If it does not start
--------------------
- "error while loading shared libraries": a library the AppImage should carry from the host is
  missing; check the output of the launcher for the name.
- "No Vulkan 1.3 graphics card found": update the driver. On NVIDIA the proprietary driver is
  required (nouveau has no Vulkan 1.3).
- Steam starts another program instead of the game, or exits at once: the static AppRun clears
  Steam's LD_PRELOAD overlay, which the AppImage's glibc cannot load; make sure the shortcut
  runs the AppImage itself (not an extracted folder copied elsewhere).
- A crash or a black screen: open "Game log" in the launcher, or send
  ~/.local/share/sotc/user/last_run.log, user/events.log and the newest file in
  user/crashes/ with an issue.


Building it yourself
--------------------
  git clone --recursive <this repository>
  bash packaging/linux/ci-deps.sh        # Ubuntu 24.04: the libraries 24.04 lacks or has too old
  bash build.sh                          # out/bb-probe, out/gpu/libbbgpu.so
  PATH="$PWD/out/venv/bin:$PATH" bash packaging/linux/build.sh
                                         # dist/SotC-x86_64.AppImage

Build on Ubuntu 24.04 (glibc 2.39): built on a newer distribution, the AppImage needs that
distribution's glibc and refuses to start on SteamOS and Debian. SOTC_MAX_GLIBC raises the
limit for a local build.

License: GPL-2.0-or-later. The port is based on bloodborne_pc (loader, runtime and launcher)
and shadPS4 (Vulkan video core). Shadow of the Colossus is a trademark of Sony Interactive
Entertainment; this project is not affiliated with Sony or Bluepoint Games.
