/**
 * The size and position of a window
 *
 * This file is part of pdfpc.
 *
 * Copyright 2020 Evgeny Stambulchik
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

namespace pdfpc.Window {
    public class Geometry {
        public int width;
        public int height;
        public int x_offset = int.MIN;
        public int y_offset = int.MIN;

        public Geometry(string description) {
            int colonIndex = description.index_of(":");
            if (colonIndex >= 0) {
                width = int.parse(description.substring(0, colonIndex));
                height = int.parse(description.substring(colonIndex + 1));
                if (width < 1 || height < 1) {
                    GLib.printerr(
                        "Failed to parse %s as a window geometry\n",
                        description
                    );
                    Process.exit(1);
                }
            } else {
                GLib.printerr(
                    "Failed to parse %s as a window geometry\n",
                    description
                );
                Process.exit(1);
            }
        }
    }
}
