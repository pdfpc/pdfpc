/**
 * Slide renderer
 *
 * This file is part of pdf-presenter-console.
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

using GLib;

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Renderer base class needed to be extended by every slide renderer.
     */
    public abstract class Renderer.Base: Object
    {
        /**
         * Metadata object to render slides for
         */
        protected Metadata.Base metadata;

        /**
         * Width to render to
         */
        protected int width;

        /**
         * Height to render to
         */
        protected int height;

        /**
         * Base constructor taking a metadata object as well as the desired
         * render width and height as parameters.
         */
        public Base( Metadata.Base metadata, int width, int height ) {
            this.metadata = metadata;
            this.width = width;
            this.height = height;
        }

        /**
         * Return the registered metadata object
         */
        public Metadata.Base get_metadata() {
            return this.metadata;
        }

        /**
         * Return the desired render width
         */
        public int get_width() {
            return this.width;
        }

        /**
         * Return the desired render height
         */
        public int get_height() {
            return this.height;
        }

        /**
         * Render the given slide_number to a Gdk.Pixmap and return it.
         *
         * If the requested slide is not available an
         * RenderError.SLIDE_DOES_NOT_EXIST error should be thrown.
         */
        public abstract Gdk.Pixmap render_to_pixmap( int slide_number ) 
            throws RenderError;

        /**
         * Fill the display with black. Useful for last "slide" or for fading
         * to black at certain points in the presentation.
         */
        public abstract Gdk.Pixmap fade_to_black();
    }

    /**
     * Error domain used for every render error, which might occur
     */
    public errordomain Renderer.RenderError {
        SLIDE_DOES_NOT_EXIST;
    }
}
