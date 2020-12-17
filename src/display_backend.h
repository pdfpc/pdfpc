/**
 * Helper functions to detect current gdk backend
 *
 * This file is part of pdfpc.
 *
 * Copyright 2017 Andreas Bilke
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
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

#ifndef DISPLAY_BACKEND_H
#define DISPLAY_BACKEND_H

#include <stdbool.h>

bool is_Wayland_backend();
bool is_X11_backend();
bool is_Quartz_backend();

#endif
