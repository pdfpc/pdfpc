/**
 * Presentation window
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2012, 2015, 2017 Andreas Bilke
 * Copyright 2013 Gabor Adam Toth
 * Copyright 2014 Andy Barry
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
     * Window showing the currently active slide to be presented on a beamer
     */
    public class Presentation : ControllableWindow {
        /**
         * Base constructor instantiating a new presentation window
         */
        public Presentation(PresentationController controller,
            int screen_num, bool windowed, int width = -1, int height = -1) {
            bool interactive = false;
            if (Options.single_screen || Options.presentation_interactive) {
                interactive = true;
            }
            base(controller, interactive, screen_num, windowed, width, height);

            this.title = "pdfpc - presentation (%s)".
                printf(controller.metadata.get_title());

            this.controller.update_request.connect(this.update);

            this.main_view.transitions_enabled = true;
            this.main_view.entering_slide.connect(this.on_entering_slide);

            // TODO: update the ratio on document reload
            double ratio = metadata.get_page_width()/metadata.get_page_height();
            var frame = new Gtk.AspectFrame(null, 0.5f, 0.5f,
                (float) ratio, false);
            frame.add(overlay_layout);

            this.add_top_container(frame);
        }

        /**
         * Update the display
         */
        public void update() {
            this.visible = !this.controller.hidden;

            if (this.controller.frozen) {
                return;
            }

            bool old_disabled = this.main_view.disabled;
            if (this.controller.faded_to_black) {
                this.main_view.disabled = true;
            } else {
                this.main_view.disabled = false;
            }

            bool force = old_disabled != this.main_view.disabled;
            this.main_view.display(this.controller.current_slide_number, force);
        }

        private void on_entering_slide(int slide_number) {
            this.controller.start_autoadvance_timer(slide_number);
        }
    }
}
