#ifndef __PDFPC_HELPER_H__
#define __PDFPC_HELPER_H__

#include <gdk/gdk.h>

gboolean pdfpc_helper_display_is_wayland(GdkDisplay* display);
gboolean pdfpc_helper_display_is_x11(GdkDisplay* display);

#endif
