/**
 * Spezialized Video View
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

namespace pdfpc {
    /**
     * View which holds gtksinks from gstreamer and place it at the correct
     * position within a Gtk.Overlay setting for a slide with an embedded
     * video.
     */
    public class View.Video: Gtk.Fixed {
        private List<Gtk.Widget> videos = null;

        public Video() {
            this.videos = new List<Gtk.Widget>();
        }

        public void add_video(Gtk.Widget video, Gdk.Rectangle position) {
            video.set_size_request(position.width, position.height);
            this.put(video, position.x, position.y);
            this.videos.append(video);
            video.get_window().set_pass_through(true);
            this.show_all();
        }

        public void resize_video(Gtk.Widget video, Gdk.Rectangle position) {
            if (this.videos.find(video) != null) {
                video.set_size_request(position.width, position.height);
                this.move(video, position.x, position.y);
            }
        }

        public void remove_video(Gtk.Widget video) {
            if (this.videos.find(video) != null) {
                this.remove(video);
                this.videos.remove(video);
            }
        }
    }
}
