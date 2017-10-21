#include "display_backend.h"

#include <stdio.h>

#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif

bool is_Wayland_backend() {
    GdkDisplay *gdk_display = gdk_display_get_default();
    #ifdef GDK_WINDOWING_WAYLAND
    if (GDK_IS_WAYLAND_DISPLAY(gdk_display)) {
        return true;
    }
    #endif

    return false;
}

bool is_X11_backend() {
    GdkDisplay *gdk_display = gdk_display_get_default();
    #ifdef GDK_WINDOWING_X11
    if (GDK_IS_X11_DISPLAY(gdk_display)) {
        return true;
    }
    #endif

    return false;
}

