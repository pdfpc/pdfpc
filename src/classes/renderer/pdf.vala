/**
 * Pdf renderer
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
     * Pdf slide renderer
     */
    public class Renderer.Pdf : Renderer.Base, Renderer.Caching {
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
         * The scaling factor needed to render the pdf page to the desired size.
         */
        protected double scaling_factor;

        /**
         * The area of the pdf which shall be displayed
         */
        protected Metadata.Area area;

        /**
         * Cache store to be used
         */
        public Renderer.Cache.Base? cache { get; protected set; default = null; }

        /**
         * Base constructor taking a pdf metadata object as well as the desired
         * render width and height as parameters.
         *
         * The pdf will always be rendered to fill up all available space. If
         * the proportions of the rendersize do not fit the proportions of the
         * pdf document the renderspace is filled up completely cutting of a
         * part of the pdf document.
         */
        public Pdf(Metadata.Pdf metadata, int width, int height, Metadata.Area area) {
            base(metadata, width, height);

            this.area = area;

            // Calculate the scaling factor needed.
            this.scaling_factor = Math.fmin(width / metadata.get_page_width(),
                height / metadata.get_page_height());
            this.width = (int) (metadata.get_page_width() * this.scaling_factor);
            this.height = (int) (metadata.get_page_height() * this.scaling_factor);

            if (!Options.disable_caching) {
                this.cache = Renderer.Cache.create(metadata);
                if (this.cache.allows_prerendering())
                    this.prerender.begin();
            }
        }

        /**
         * Render the given slide_number to a Cairo.Context and return it.
         *
         * If the requested slide is not available an
         * RenderError.SLIDE_DOES_NOT_EXIST error is thrown.
         */
        public override void render(Cairo.Context? context, int slide_number, int display_width = 0,
            int display_height = 0)
            throws Renderer.RenderError {

            var metadata = this.metadata as Metadata.Pdf;

            // Check if a valid page is requested, before locking anything.
            if (slide_number < 0 || slide_number >= metadata.get_slide_count()) {
                throw new Renderer.RenderError.SLIDE_DOES_NOT_EXIST(
                    "The requested slide '%i' does not exist.", slide_number);
            }

            Gdk.Pixbuf? pixbuf = null;
            // If caching is enabled check for the page in the cache
            if (this.cache != null)
                pixbuf = this.cache.retrieve(slide_number);
            
            if (pixbuf == null) {
                // Retrieve the Poppler.Page for the page to render
                var page = metadata.get_document().get_page(slide_number);

                // A lot of Pdfs have transparent backgrounds defined. We render
                // every page before a white background because of this.
                Cairo.ImageSurface current_slide = new Cairo.ImageSurface(Cairo.Format.RGB24,
                    this.width, this.height);
                Cairo.Context cr = new Cairo.Context(current_slide);

                cr.set_source_rgb(255, 255, 255);
                cr.rectangle(0, 0, this.width, this.height);
                cr.fill();

                cr.scale(this.scaling_factor, this.scaling_factor);
                cr.translate(-metadata.get_horizontal_offset(this.area),
                    -metadata.get_vertical_offset(this.area));
                page.render(cr);

                pixbuf = Gdk.pixbuf_get_from_surface(current_slide, 0, 0, this.width, this.height);
                // If the cache is enabled store the newly rendered pixmap
                if (this.cache != null) {
                    this.cache.store(slide_number, pixbuf);
                }
            }

            if (context == null)
                return;

            Gdk.Pixbuf pixbuf_scaled = pixbuf.scale_simple(display_width, display_height,
                Gdk.InterpType.BILINEAR);
            Gdk.cairo_set_source_pixbuf(context, pixbuf_scaled, 0, 0);
            context.rectangle(0, 0, pixbuf_scaled.get_width(), pixbuf_scaled.get_height());
            context.fill();
        }

        public async void prerender() {
            uint page_count = this.metadata.get_slide_count();
            for (int i = 0; i < page_count; i++) {
                Idle.add(this.prerender.callback);
                yield;

                if (i == 0)
                    this.prerendering_started();

                // We do not care about the result, as the
                // rendering function stores the rendered
                // pixmap in the cache if it is enabled. This
                // is exactly what we want.
                try {
                    this.render(null, i);
                } catch(Renderer.RenderError e) {
                    error("Could not render page '%i' while pre-rendering: %s", i, e.message);
                }

                // Inform possible observers about the cached slide
                this.slide_prerendered();
            }
            this.prerendering_completed();
        }
    }
}

