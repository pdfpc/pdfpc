#include "pdfpc-helper.h"

#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

gboolean pdfpc_helper_display_is_wayland(GdkDisplay* display) {
    #ifdef GDK_WINDOWING_WAYLAND
    if (GDK_IS_WAYLAND_DISPLAY(display)) {
        return TRUE;
    }
    #endif

    return FALSE;
}

gboolean pdfpc_helper_display_is_x11(GdkDisplay* display) {
    #ifdef GDK_WINDOWING_X11
    if (GDK_IS_X11_DISPLAY(display)) {
        return TRUE;
    }
    #endif

    return FALSE;
}
