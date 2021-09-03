/**
 * Image renderer
 *
 * This file is part of pdfpc.
 *
 * Copyright 2021 Evgeny Stambulchik
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

namespace pdfpc.Renderer {
    public class Image {
       /**
         * Load an (SVG) image, replacing a substring in it in special cases
         */
        public static Cairo.Surface? render(string filename,
            int width, int height) {
            // attempt to load from a local path (if the user hasn't installed)
            // if that fails, attempt to load from the global path
            string load_icon_path;
            if (Options.no_install) {
                load_icon_path = Path.build_filename(Paths.SOURCE_PATH, "icons",
                    filename);
            } else {
                load_icon_path = Path.build_filename(Paths.SHARE_PATH, "icons",
                    filename);
            }
            File icon_file = File.new_for_path(load_icon_path);

            try {
                Gdk.Pixbuf pixbuf;
                if (filename == "highlight.svg") {
                    uint8[] contents;
                    string etag_out;
                    icon_file.load_contents(null, out contents, out etag_out);

                    string buf = (string) contents;
                    buf = buf.replace("pointer_color", Options.pointer_color);

                    MemoryInputStream stream =
                        new MemoryInputStream.from_data(buf.data);

                    pixbuf = new Gdk.Pixbuf.from_stream_at_scale(stream,
                        width, width, true);
                } else {
                    pixbuf = new Gdk.Pixbuf.from_file_at_scale(load_icon_path,
                        width, width, true);
                }

                return Gdk.cairo_surface_create_from_pixbuf(pixbuf, 0, null);
            } catch (Error e) {
                GLib.printerr("Warning: Could not load image %s (%s)\n",
                    load_icon_path, e.message);
                return null;
            }
        }
    }
}
