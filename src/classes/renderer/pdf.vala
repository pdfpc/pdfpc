/**
 * Pdf renderer
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2012, 2015 Andreas Bilke
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
     * Pdf slide renderer
     */
    public class Renderer.Pdf : Object {
        /**
         * Metadata object to render slides for
         */
        public Metadata.Pdf metadata { get; protected set; }

        /**
         * Cache store to be used
         */
        protected Renderer.Cache cache { get; set; }

        /**
         * Base constructor taking a pdf metadata object as well as the desired
         * render width and height as parameters.
         *
         * The pdf will always be rendered to fill up all available space. If
         * the proportions of the rendersize do not fit the proportions of the
         * pdf document the renderspace is filled up completely cutting of a
         * part of the pdf document.
         */
        public Pdf(Metadata.Pdf metadata) {
            this.metadata = metadata;

            this.cache = new Renderer.Cache();
        }

        /**
         * Render the given slide_number to a Cairo.ImageSurface and return it.
         *
         * If the requested slide is not available an
         * RenderError.SLIDE_DOES_NOT_EXIST error is thrown.
         */
        public Cairo.ImageSurface render(int slide_number,
            Metadata.Area area, int width, int height,
            bool force_cache = false, bool permanent_cache = false)
            throws Renderer.RenderError {

            var metadata = this.metadata;

            // Check if a valid page is requested, before locking anything.
            if (slide_number < 0 || slide_number >= metadata.get_slide_count()) {
                throw new Renderer.RenderError.SLIDE_DOES_NOT_EXIST(
                    "The requested slide '%i' does not exist.", slide_number);
            }

            CachedPageProps props = new CachedPageProps(slide_number,
                width, height);

            // Check for the page in the cache
            Cairo.ImageSurface cache_content;
            if ((cache_content = this.cache.retrieve(props)) != null) {
                return cache_content;
            }

            // Measure the time to render the page
            Timer timer = new Timer();

            // Retrieve the Poppler.Page for the page to render
            var page = metadata.get_document().get_page(slide_number);

            // A lot of Pdfs have transparent backgrounds defined. We render
            // every page before a white background because of this.
            Cairo.ImageSurface surface =
                new Cairo.ImageSurface(Cairo.Format.RGB24, width, height);
            Cairo.Context cr = new Cairo.Context(surface);

            cr.set_source_rgb(255, 255, 255);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            // Calculate the scaling factor and the offsets for centering
            double full_page_width, corrected_page_width, full_page_height, corrected_page_height;
            page.get_size(out full_page_width, out full_page_height);
            corrected_page_width = metadata.get_corrected_page_width(full_page_width);
            corrected_page_height = metadata.get_corrected_page_height(full_page_height);

            double scaling_factor, v_offset, h_offset;
            if (width/corrected_page_width < height/corrected_page_height) {
                scaling_factor = width/corrected_page_width;
                h_offset = 0;
                v_offset = (height/scaling_factor - corrected_page_height)/2;
            } else {
                scaling_factor = height/corrected_page_height;
                h_offset = (width/scaling_factor - corrected_page_width)/2;
                v_offset = 0;
            }
            cr.scale(scaling_factor, scaling_factor);

            cr.translate(-metadata.get_horizontal_offset(area, full_page_width) + h_offset,
                -metadata.get_vertical_offset(area, full_page_height) + v_offset);
            page.render(cr);

            timer.stop();
            double rtime = timer.elapsed();
            if (Options.cache_debug) {
                printerr("Render time of [%d] (%dx%d) = %g s\n",
                    slide_number, width, height, rtime);
            }

            // If the cache is enabled store the newly rendered pixmap, but
            // only if it has taken a significant time to render
            if (force_cache || rtime > Options.cache_min_rtime/1000.0) {
                // keep very "precious" slides permanently
                if (rtime > Options.cache_max_rtime) {
                    permanent_cache = true;
                }
                this.cache.store(props, surface, permanent_cache);
            }

            return surface;
        }

        public Cairo.ImageSurface fade_to_black(int width, int height) {
            Cairo.ImageSurface surface =
                new Cairo.ImageSurface(Cairo.Format.RGB24, width, height);
            Cairo.Context cr = new Cairo.Context(surface);

            cr.set_source_rgb(0, 0, 0);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            double scaling_factor = Math.fmax(width/metadata.get_page_width(),
                height/metadata.get_page_height());
            cr.scale(scaling_factor, scaling_factor);

            return surface;
        }

        /**
         * Invalidate the whole cache (if the document is reloaded/changed)
         */
        public void invalidate_cache() {
            this.cache.invalidate();
        }
    }

    /**
     * Error domain used for every render error, which might occur
     */
    public errordomain Renderer.RenderError {
        SLIDE_DOES_NOT_EXIST;
    }
}

