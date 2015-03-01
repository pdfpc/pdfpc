/**
 * Default slide view
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
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
     * Basic view class which is usable with any renderer.
     */
    public class View.Default : View.Base, View.Behaviour.Decoratable {
        public enum Alignment {
            START = 0,
            CENTER = 1,
            END = 2
        }

        public Alignment horizontal_align = Alignment.CENTER;
        public Alignment vertical_align = Alignment.CENTER;

        /**
         * The currently displayed slide
         */
        protected int current_slide_number;

        /**
         * The number of slides in the presentation
         */
        protected int n_slides;

        protected int slide_limit;

        protected bool black = false;

        /**
         * List to store all associated behaviours
         */
        protected GLib.List<View.Behaviour.Base> behaviours = new GLib.List<View.Behaviour.Base>();

        /**
         * Base constructor taking the renderer to use as an argument
         */
        public Default(Renderer.Base renderer) {
           base(renderer);

           // As we are using our own kind of double buffer and blit in a one
           // time action, we do not need gtk to double buffer as well.
           this.set_double_buffered(false);

           this.current_slide_number = 0;

           this.n_slides = (int) renderer.metadata.get_slide_count();
           this.slide_limit = this.n_slides + 1;

           // Render the initial page on first realization.
           this.add_events(Gdk.EventMask.STRUCTURE_MASK);
           this.realize.connect(() => {
                this.display( this.current_slide_number );
           });
        }

        /**
         * Associate a new Behaviour with this View
         *
         * The implementation supports an arbitrary amount of different
         * behaviours.
         */
        public void associate_behaviour(Behaviour.Base behaviour) {
            this.behaviours.append(behaviour);
            try {
                behaviour.associate(this);
            } catch(Behaviour.AssociationError e) {
                error("Behaviour association failure: %s", e.message);
            }
        }

        /**
         * Display a specific slide number
         *
         * If the slide number does not exist a
         * RenderError.SLIDE_DOES_NOT_EXIST is thrown
         */
        public override void display(int slide_number, bool force_redraw=false) {
            this.black = false;
            // If the slide is out of bounds render the outer most slide on
            // each side of the document.
            if (slide_number < 0) {
                slide_number = 0;
            }
            if (slide_number >= this.slide_limit) {
                slide_number = this.slide_limit - 1;
            }

            if (!force_redraw && slide_number == this.current_slide_number) {
                // The slide does not need to be changed, as the correct one is
                // already shown.
                return;
            }

            // Notify all listeners
            this.leaving_slide(this.current_slide_number, slide_number);

            this.current_slide_number = slide_number;

            // Have Gtk update the widget
            this.queue_draw();

            this.entering_slide(this.current_slide_number);
        }

        /**
         * Fill everything with black
         */
        public override void fade_to_black() {
            this.black = true;
            this.queue_draw();
        }

        /**
         * Redraw the current slide. Useful for example when exiting from fade_to_black
         */
        public override void redraw() throws Renderer.RenderError {
            this.display(this.current_slide_number, true);
        }

        /**
         * Return the currently shown slide number
         */
        public override int get_current_slide_number() {
            return this.current_slide_number;
        }

        /**
         * This method is called by Gdk every time the widget needs to be redrawn.
         *
         * The implementation does a simple blit from the internal pixmap to
         * the window surface.
         */
        public override bool draw(Cairo.Context cr) {
            int width = this.get_allocated_width(),
                height = this.get_allocated_height(),
                slide_width = this.renderer.width,
                slide_height = this.renderer.height;
            double scale = double.min((double) width / slide_width, (double) height / slide_height);

            cr.set_source_rgb(0, 0, 0);
            cr.rectangle(0, 0, width, height);
            cr.fill();
            if (this.black)
                return true;

            cr.translate(this.horizontal_align * (width - slide_width * scale) / 2,
                this.vertical_align * (height - slide_height * scale) / 2);
            try {
                this.renderer.render(cr, this.current_slide_number, (int) (slide_width * scale),
                    (int) (slide_height * scale));
            } catch( Renderer.RenderError e ) {
                error("The pdf page %d could not be rendered: %s", this.current_slide_number,
                    e.message);
            }

            // We are the only ones drawing on this context skip everything
            // else.
            return true;
        }
    }
}

