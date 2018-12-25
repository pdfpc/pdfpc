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
        public Presentation(PresentationController presentation_controller,
            int screen_num, int width = -1, int height = -1) {
            base(screen_num, width, height);
            this.presentation_controller = presentation_controller;

            this.role = "presentation";
            this.title = "pdfpc - presentation (%s)".printf(metadata.get_document().get_title());

            this.destroy.connect((source) => presentation_controller.quit());

            this.presentation_controller.update_request.connect(this.update);

            Gdk.Rectangle scale_rect;
            this.view = new View.Pdf.from_fullscreen(this,
                this.screen_geometry.width, this.screen_geometry.height,
                Metadata.Area.CONTENT,
                Options.black_on_end, true, out scale_rect);

            if (!Options.disable_caching) {
                this.view.get_renderer().cache = Renderer.Cache.create(metadata);
            }

            this.overlay_layout.add(this.view);

            this.overlay_layout.set_size_request(
                this.main_view.get_renderer().width / this.gdk_scale,
                this.main_view.get_renderer().height / this.gdk_scale
            );

            this.add(overlay_layout);

            this.key_press_event.connect(this.presentation_controller.key_press);
            this.button_press_event.connect(this.presentation_controller.button_press);
            this.scroll_event.connect(this.presentation_controller.scroll);

            this.presentation_controller.register_controllable(this);
        }

        /**
         * Set the presentation controller which is notified of keypresses and
         * other observed events
         */
        public void set_controller(PresentationController controller) {
            this.presentation_controller = controller;
        }

        /**
         * Update the display
         */
        public void update() {
            this.visible = !this.presentation_controller.hidden;

            if (this.presentation_controller.faded_to_black) {
                this.view.fade_to_black();
                return;
            }
            if (this.presentation_controller.frozen)
                return;

            try {
                this.view.display(this.presentation_controller.current_slide_number, true);
            } catch (Renderer.RenderError e) {
                GLib.printerr("The pdf page %d could not be rendered: %s\n",
                    this.presentation_controller.current_slide_number, e.message );
                Process.exit(1);
            }
        }

        /**
         * Set the cache observer for the Views on this window
         *
         * This method takes care of registering all Prerendering Views used by
         * this window correctly with the CacheStatus object to provide acurate
         * cache status measurements.
         */
        public void set_cache_observer(CacheStatus observer) {
            observer.monitor_view(this.view);
        }
    }
}

