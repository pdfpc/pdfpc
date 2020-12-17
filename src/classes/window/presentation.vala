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
    public class Presentation : Fullscreen, Controllable {
        /**
         * The only view is the main view.
         */
        public View.Pdf main_view {
            get {
                return this.view;
            }
        }

        /**
         * View containing the slide to show
         */
        protected View.Pdf view;

        /**
         * Base constructor instantiating a new presentation window
         */
        public Presentation(PresentationController controller,
            int screen_num, bool windowed, int width = -1, int height = -1) {
            base(controller, false, screen_num, windowed, width, height);

            this.controller.reload_request.connect(this.on_reload);
            this.controller.update_request.connect(this.update);
            this.controller.zoom_request.connect(this.on_zoom);

            this.view = new View.Pdf.from_fullscreen(this, false, true);
            this.view.transitions_enabled = true;
            this.view.entering_slide.connect(this.on_entering_slide);

            this.overlay_layout.add(this.view);

            // TODO: update the ratio on document reload
            double ratio = metadata.get_page_width()/metadata.get_page_height();
            var frame = new Gtk.AspectFrame(null, 0.5f, 0.5f,
                (float) ratio, false);
            frame.add(overlay_layout);
            this.add(frame);
        }

        /**
         * Called on document reload.
         * TODO: in principle the document geometry may change!
         */
        public void on_reload() {
            this.view.invalidate();
        }

        /**
         * Update the display
         */
        public void update() {
            this.visible = !this.controller.hidden;

            if (this.controller.frozen)
                return;

            bool old_disabled = this.view.disabled;
            if (this.controller.faded_to_black) {
                this.view.disabled = true;
            } else {
                this.view.disabled = false;
            }

            bool force = old_disabled != this.view.disabled;
            this.view.display(this.controller.current_slide_number, force);
        }

        private void on_zoom(PresentationController.ScaledRectangle? rect) {
            this.main_view.display(this.controller.current_slide_number,
                true, rect);
        }

        private void on_entering_slide(int slide_number) {
            this.controller.start_autoadvance_timer(slide_number);
        }
    }
}
