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
         * The surface containing the currently shown slide
         */
        protected Cairo.ImageSurface current_slide;

        /**
         * The number of slides in the presentation
         */
        protected int n_slides;

        protected int slide_limit;

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
                try {
                    this.display( this.current_slide_number );
                } catch( Renderer.RenderError e ) {
                    // There should always be a page 0 but you never know.
                    error("Could not render initial page %d: %s",
                        this.current_slide_number, e.message);
                }
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
        public override void display(int slide_number, bool force_redraw=false)
            throws Renderer.RenderError {

            // If the slide is out of bounds render the outer most slide on
            // each side of the document.
            if (slide_number < 0) {
                slide_number = 0;
            }
            if (slide_number >= this.slide_limit) {
                slide_number = this.slide_limit - 1;
            }

            if (!force_redraw && slide_number == this.current_slide_number &&
                this.current_slide != null) {
                // The slide does not need to be changed, as the correct one is
                // already shown.
                return;
            }

            // Notify all listeners
            this.leaving_slide(this.current_slide_number, slide_number);

            // Render the requested slide
            // An exception is thrown here, if the slide can not be rendered.
            if (slide_number < this.n_slides)
                this.current_slide = this.renderer.render_to_surface(slide_number);
            else
                this.current_slide = this.renderer.fade_to_black();
            this.current_slide_number = slide_number;

            // Have Gtk update the widget
            this.queue_draw();

            this.entering_slide(this.current_slide_number);
        }

        /**
         * Fill everything with black
         */
        public override void fade_to_black() {
            this.current_slide = this.renderer.fade_to_black();
            this.queue_draw_area(0, 0, this.renderer.width, this.renderer.height);
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
                slide_width = this.current_slide.get_width(),
                slide_height = this.current_slide.get_height();
            double scale = double.min((double) width / slide_width, (double) height / slide_height);

            cr.set_source_rgb(0, 0, 0);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            Gdk.Pixbuf pixbuf = Gdk.pixbuf_get_from_surface(this.current_slide, 0, 0, slide_width,
                slide_height);
            Gdk.Pixbuf pixbuf_scaled = pixbuf.scale_simple((int) (slide_width * scale),
                (int) (slide_height * scale), Gdk.InterpType.BILINEAR);
            Gdk.cairo_set_source_pixbuf(cr, pixbuf_scaled, 0, 0);
            cr.rectangle(0, 0, pixbuf.get_width(), pixbuf.get_height());
            cr.fill();

            // We are the only ones drawing on this context skip everything
            // else.
            return true;
        }
    }
}

