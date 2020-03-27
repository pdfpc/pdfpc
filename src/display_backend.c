/**
 * Helper functions to detect current gdk backend
 *
 * This file is part of pdfpc.
 *
 * Copyright 2017 Andreas Bilke
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "display_backend.h"

#include <stdio.h>

#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif
#ifdef GDK_WINDOWING_QUARTZ
#include <gdk/gdkquartz.h>
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

bool is_Quartz_backend() {
    GdkDisplay *gdk_display = gdk_display_get_default();
    #ifdef GDK_WINDOWING_QUARTZ
    if (GDK_IS_QUARTZ_DISPLAY(gdk_display)) {
        return true;
    }
    #endif

    return false;
}
