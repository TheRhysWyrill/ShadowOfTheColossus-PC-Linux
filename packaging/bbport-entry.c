// Entry point of the packaged port (the AppImage's): a static program that removes the host's
// library injection from the environment, then runs the real wrapper (TARGET) beside it.
//
// Steam starts every non-Steam game with LD_PRELOAD=.../gameoverlayrenderer.so (any
// compatibility tool, Steam Deck included). Loaded into this package's own glibc, the overlay
// cannot find its libGL.so.1 and the first dynamic program, the wrapper's bash, exits at once:
// "error while loading shared libraries: libGL.so.1". Being static, this program is not affected.
// LD_LIBRARY_PATH, GTK_PATH and the like name host libraries just as incompatible with the
// package; Steam's Vulkan layers (overlay, fossilize) are host libraries too.
//
// The wrapper is started by its path next to this program (/proc/self/exe): the AppImage runtime
// does not change the working directory, so a relative name would look in the caller's.
#define _GNU_SOURCE
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef TARGET
#error "TARGET: the wrapper to run"
#endif

static void drop(const char* name) {
    const char* value = getenv(name);
    if (!value || !*value) {
        unsetenv(name);
        return;
    }
    // Kept for diagnostics (the launcher's log shows the environment problems).
    char saved[128];
    snprintf(saved, sizeof saved, "BB_HOST_%s", name);
    setenv(saved, value, 1);
    unsetenv(name);
}

int main(int argc, char** argv) {
    (void)argc;
    static const char* const host_only[] = {
        "LD_PRELOAD", "LD_LIBRARY_PATH", "LD_AUDIT", "GTK_PATH", "GTK_MODULES", "GTK_EXE_PREFIX",
        "GIO_EXTRA_MODULES", "GDK_PIXBUF_MODULEDIR", "PYTHONHOME", "PYTHONPATH",
    };
    for (size_t i = 0; i < sizeof host_only / sizeof host_only[0]; ++i) {
        drop(host_only[i]);
    }
    setenv("DISABLE_VK_LAYER_VALVE_steam_overlay_1", "1", 1);
    setenv("DISABLE_VK_LAYER_VALVE_steam_fossilize_1", "1", 1);

    char exe[PATH_MAX];
    ssize_t length = readlink("/proc/self/exe", exe, sizeof exe - 1);
    if (length <= 0 || (size_t)length >= sizeof exe - 1) {
        perror("bbport: /proc/self/exe");
        return 127;
    }
    exe[length] = '\0';
    char* slash = strrchr(exe, '/');
    if (!slash) {
        fprintf(stderr, "bbport: cannot find the AppImage folder\n");
        return 127;
    }
    slash[1] = '\0';

    size_t dir_length = strlen(exe);
    static const char target[] = TARGET;
    char script[PATH_MAX];
    if (dir_length + sizeof target > sizeof script) {
        fprintf(stderr, "bbport: the AppImage path is too long\n");
        return 127;
    }
    memcpy(script, exe, dir_length);
    memcpy(script + dir_length, target, sizeof target);
    argv[0] = script;
    execv(script, argv);
    perror("bbport: " TARGET);
    return 127;
}
