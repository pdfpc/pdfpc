/**
 * Default slide view
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2015 Andreas Bilke
 * Copyright 2015 Robert Schroll
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
    public class View.Base : Gtk.DrawingArea {
        /**
         * Signal fired every time a slide is about to be left
         */
        public signal void leaving_slide(int from, int to);

        /**
         * Signal fired every time a slide is entered
         */
        public signal void entering_slide(int slide_number);

        /**
         * Renderer to be used for rendering the slides
         */
        protected Renderer.Pdf renderer;

        /**
         * Return the used renderer object
         */
        public Renderer.Pdf get_renderer() {
            return this.renderer;
        }

        /**
         * Signal emitted every time a precached slide has been created
         *
         * This signal should be emitted slide_count number of times during a
         * precaching cylce.
         */
        public signal void slide_prerendered();

        /**
         * Signal emitted when the precaching cycle is complete
         */
        public signal void prerendering_completed();

        /**
         * Signal emitted when the precaching cycle just started
         */
        public signal void prerendering_started();

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

        /**
         * List to store all associated behaviours
         */
        protected GLib.List<View.Behaviour.Base> behaviours = new GLib.List<View.Behaviour.Base>();

        /**
         * Base constructor taking the renderer to use as an argument
         */
        public Base(Renderer.Pdf renderer) {
            this.renderer = renderer;
            this.set_size_request(renderer.width, renderer.height);

            this.current_slide_number = 0;

            this.n_slides = (int) renderer.metadata.get_slide_count();

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

                 // Start the prerender cycle if the renderer supports caching
                 // and the used cache engine allows prerendering.
                 // Executing the cycle here to ensure it is executed within the
                 // Gtk event loop. If it is not proper Gdk thread handling is
                 // impossible.
                 if (renderer.cache != null && renderer.cache.allows_prerendering()) {
                     this.register_prerendering();
                 }
            });
        }

        /**
         * Start a thread to prerender all slides this view might display at
         * some time.
         *
         * This method may only be called from within the Gtk event loop, as
         * thread handling is borked otherwise.
         */
        protected void register_prerendering() {
            // The pointer is needed to keep track of the slide progress inside
            // the prerender function
            int* i = null;
            // The page_count will be transfered into the lamda function as
            // well.
            var page_count = this.get_renderer().metadata.get_slide_count();

            this.prerendering_started();

            Idle.add(() => {
                if (i == null) {
                    i = malloc(sizeof(int));
                    *i = 0;
                }

                // We do not care about the result, as the
                // rendering function stores the rendered
                // pixmap in the cache if it is enabled. This
                // is exactly what we want.
                try {
                    this.get_renderer().render_to_surface(*i);
                } catch(Renderer.RenderError e) {
                    error("Could not render page '%i' while pre-rendering: %s", *i, e.message);
                }

                // Inform possible observers about the cached slide
                this.slide_prerendered();

                // Increment one slide for each call and stop the loop if we
                // have reached the last slide
                *i = *i + 1;
                if (*i >= page_count) {
                    this.prerendering_completed();
                    free(i);
                    return false;
                } else {
                    return true;
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
        public void display(int slide_number, bool force_redraw=false)
            throws Renderer.RenderError {

            // If the slide is out of bounds render the outer most slide on
            // each side of the document.
            if (slide_number < 0) {
                slide_number = 0;
            } else if (slide_number >= this.n_slides) {
                slide_number = this.n_slides - 1;
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
            this.queue_draw_area(0, 0, this.renderer.width, this.renderer.height);

            this.entering_slide(this.current_slide_number);
        }

        /**
         * Fill everything with black
         */
        public void fade_to_black() {
            this.current_slide = this.renderer.fade_to_black();
            this.queue_draw_area(0, 0, this.renderer.width, this.renderer.height);
        }

        /**
         * Redraw the current slide. Useful for example when exiting from fade_to_black
         */
        public void redraw() throws Renderer.RenderError {
            this.display(this.current_slide_number, true);
        }

        /**
         * Return the currently shown slide number
         */
        public int get_current_slide_number() {
            return this.current_slide_number;
        }

        /**
         * This method is called by Gdk every time the widget needs to be redrawn.
         *
         * The implementation does a simple blit from the internal pixmap to
         * the window surface.
         */
        public override bool draw(Cairo.Context cr) {
            cr.set_source_surface(this.current_slide, 0, 0);
            cr.rectangle(0, 0, this.current_slide.get_width(), this.current_slide.get_height());
            cr.fill();

            // We are the only ones drawing on this context skip everything
            // else.
            return true;
        }
    }
}

