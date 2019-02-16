/**
 * Spezialized Video View
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

namespace pdfpc {
    /**
     * View which holds gtksinks from gstreamer and place it at the correct
     * position within a Gtk.Overlay setting for a slide with an embedded
     * video.
     */
    public class View.Video: Gtk.Fixed {
        private Gtk.Widget video = null;

        public void add_video(Gtk.Widget video, Gdk.Rectangle position) {
            if (this.video == null) {
                video.set_size_request(position.width, position.height);
                this.put(video, position.x, position.y);
                this.video = video;
                this.show_all();
            }
        }

        public void resize_video(Gdk.Rectangle position) {
            if (this.video != null) {
                this.video.set_size_request(position.width, position.height);
                this.move(this.video, position.x, position.y);
            }
        }

        public void remove_video() {
            if (this.video != null) {
                this.remove(this.video);
                this.video = null;
            }
        }
    }
}
