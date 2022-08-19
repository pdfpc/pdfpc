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
                if (width < 1) {
                    GLib.printerr(
                        "The string %s does not specify a positive width\n",
                        description.substring(0, colonIndex)
                    );
                    GLib.printerr(
                        "Failed to parse %s as a W:H window geometry\n",
                        description
                    );
                    Process.exit(1);
                }
                if (height < 1) {
                    GLib.printerr(
                        "The string %s does not specify a positive height\n",
                        description.substring(colonIndex + 1)
                    );
                    GLib.printerr(
                        "Failed to parse %s as a W:H window geometry\n",
                        description
                    );
                    Process.exit(1);
                }
            } else {
                unowned string desc_xhpxpy;
                string desc_hpxpy;
                unowned string desc_pxpy;
                string desc_xpy;
                unowned string desc_py;
                string desc_y;
                if (
                    int.try_parse(description, out width, out desc_xhpxpy)
                    ||
                    width < 1
                ) {
                    GLib.printerr(
                        "A Failed to parse %s as a WxH[+X+Y] window geometry\n",
                        description
                    );
                    Process.exit(1);
                }
                if (desc_xhpxpy.index_of("x") != 0) {
                    GLib.printerr(
                        "B Failed to parse %s as a WxH[+X+Y] window geometry\n",
                        description
                    );
                    Process.exit(1);
                }
                desc_hpxpy = desc_xhpxpy.substring(1);
                if (int.try_parse(desc_hpxpy, out height, out desc_pxpy)) {
                    if (height < 1) {
                        GLib.printerr(
                            "C Failed to parse %s as a WxH[+X+Y] window geometry\n",
                            description
                        );
                        Process.exit(1);
                    }
                } else {
                    if (desc_pxpy.index_of("+") != 0) {
                        GLib.printerr(
                            "D Failed to parse %s as a WxH[+X+Y] window geometry\n",
                            description
                        );
                        Process.exit(1);
                    }
                    desc_xpy = desc_pxpy.substring(1);
                    if (int.try_parse(desc_xpy, out x_offset, out desc_py)) {
                        GLib.printerr(
                            "E Failed to parse %s as a WxH[+X+Y] window geometry\n",
                            description
                        );
                        Process.exit(1);
                    }
                    if (desc_py.index_of("+") != 0) {
                        GLib.printerr(
                            "F Failed to parse %s as a WxH[+X+Y] window geometry\n",
                            description
                        );
                        Process.exit(1);
                    }
                    desc_y = desc_py.substring(1);
                    if (!int.try_parse(desc_y, out y_offset)) {
                        GLib.printerr(
                            "G Failed to parse %s as a WxH[+X+Y] window geometry\n",
                            description
                        );
                        Process.exit(1);
                    }
                }
            }
        }
    }
}
