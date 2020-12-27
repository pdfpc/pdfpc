/**
 * QR code window
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
    /**
     * Window showing QR code of the connection properties
     */
    public class QRCode : Gtk.DrawingArea {

        public QRCode(PresentationController controller, double size) {
            var rs = controller.rest_server;
            if (rs == null) {
                return;
            }
            var conn_str = rs.get_connection_info();
            if (conn_str == null) {
                return;
            }

            this.get_style_context().add_class("qrcode");
            this.halign = Gtk.Align.CENTER;
            this.valign = Gtk.Align.CENTER;
            this.can_focus = true;

            var qrcode = new Qrencode.QRcode.encodeString(conn_str,
                0, Qrencode.EcLevel.L, Qrencode.Mode.B8, 1);
            int width = qrcode.width;

            int scale = (int) Math.floor(size/(width + 2));
            if (scale < 1) {
                scale = 1;
            }

            int swidth = scale*width;

            // allow for one extra scaled "pixel" each side for white frame
            this.set_size_request(swidth + 2*scale, swidth + 2*scale);

            // convert to RGB format
            var buf = new uint8[3*swidth*swidth];
            for (int ix = 0; ix < width; ix++) {
                for (int iy = 0; iy < width; iy++) {
                    int idx = iy*width + ix;
                    var bit = qrcode.data[idx];
                    bool black = (bit & 1) == 1;
                    uint8 byte;
                    if (black) {
                        byte = 0x00;
                    } else {
                        byte = 0xff;
                    }
                    for (int sx = 0; sx < scale; sx++) {
                        for (int sy = 0; sy < scale; sy++) {
                            idx = (scale*iy + sy)*swidth + scale*ix + sx;
                            buf[3*idx]     = byte;
                            buf[3*idx + 1] = byte;
                            buf[3*idx + 2] = byte;
                        }
                    }
                }
            }

            var pixbuf = new Gdk.Pixbuf.from_data(buf,
                Gdk.Colorspace.RGB, false, 8, swidth, swidth, 3*swidth);

            this.draw.connect((w, cr) => {
                    // set white frame of one scaled pixel each side
                    cr.set_source_rgb(255, 255, 255);
                    cr.rectangle(0, 0, swidth + 2*scale, swidth + 2*scale);
                    cr.fill();

                    // the QR code itself
                    Gdk.cairo_set_source_pixbuf(cr, pixbuf, scale, scale);
                    cr.paint();

                    return true;
                });
        }
    }
}
