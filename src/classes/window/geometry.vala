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

        public bool default_positions() {
            return x_offset == int.MIN && y_offset == int.MIN;
        }

        private bool parse_legacy_geometry(string description, int colonIndex) {
            width = int.parse(description.substring(0, colonIndex));
            height = int.parse(description.substring(colonIndex + 1));
            if (width < 1) {
                GLib.printerr(
                    "The string %s does not specify a positive width\n",
                    description.substring(0, colonIndex)
                );
                return false;
            }
            if (height < 1) {
                GLib.printerr(
                    "The string %s does not specify a positive height\n",
                    description.substring(colonIndex + 1)
                );
                return false;
            }
            return true;
        }

        private bool is_digit(char d) {
            switch (d) {
                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7':
                case '8':
                case '9':
                    return true;
                default:
                    return false;
            }
        }

        private int parse_prefix(string desc, int pos, out int num) {
            num = 0;
            while (pos < desc.len() && is_digit(desc[pos])) {
                num *= 10;
                num += desc[pos] - 48;
                pos += 1;
            }
            return pos;
        }

        private bool parse_xish_geometry(string desc) {
            int pos = 0;
            if (desc[0] == '=') {
                pos = 1;
            }
            pos = parse_prefix(desc, pos, out width);
            if (width < 1) {
                GLib.printerr("Width must be positive\n");
                return false;
            }
            if (pos == desc.len() || (desc[pos] | 32) != 'x') {
                GLib.printerr("Expected x or X after width\n");
                return false;
            }
            pos += 1;
            pos = parse_prefix(desc, pos, out height);
            if (height < 1) {
                GLib.printerr("Height must be positive\n");
                return false;
            }
            if (pos != desc.len()) {
                int? p = parse_single_offset(desc, pos, out x_offset);
                if (p == null) {
                    GLib.printerr("No valid x offset after height\n");
                    return false;
                }
                pos = p;
                p = parse_single_offset(desc, pos, out y_offset);
                if (p == null) {
                    GLib.printerr("No valid y offset after x offset\n");
                    return false;
                }
                pos = p;
            }
            if (pos != desc.len()) {
                GLib.printerr("More characters after y offset\n");
                return false;
            }
            return true;
        }

        private int? parse_single_offset(string desc, int pos, out int num) {
            char sign = desc[pos];
            if (sign != '+' && sign != '-') {
                return null;
            }
            int res;
            pos = parse_prefix(desc, pos+1, out res);
            num = (sign == '-') ? -res : res;
            return pos;
        }

        public Geometry(string description) {
            int colonIndex = description.index_of(":");
            if (colonIndex >= 0) {
                GLib.printerr("Legacy window geometry \"%s\"\n", description);
                GLib.printerr(
                    "Support for the W:H format " +
                    "will be removed in a future version\n"
                );
                if (!parse_legacy_geometry(description, colonIndex)) {
                    GLib.printerr(
                        "Failed to parse %s as a W:H window geometry\n",
                        description
                    );
                    Process.exit(1);
                }
            } else {
                if (!parse_xish_geometry(description)) {
                   GLib.printerr(
                       "Failed to parse %s as a WxH[+X+Y] geometry\n",
                       description
                   );
                }
            }
        }
    }
}
