/**
 * Slide renderer
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011, 2012 David Vilar
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
     * Renderer base class needed to be extended by every slide renderer.
     */
    public abstract class Renderer.Base : Object {
        /**
         * Metadata object to render slides for
         */
        public Metadata.Base metadata { get; protected set; }

        /**
         * Width to render to
         */
        public int width { get; protected set; }

        /**
         * Height to render to
         */
        public int height { get; protected set; }

        /**
         * Base constructor taking a metadata object as well as the desired
         * render width and height as parameters.
         */
        public Base(Metadata.Base metadata, int width, int height) {
            this.metadata = metadata;
            this.width = width;
            this.height = height;
        }

        /**
         * Render the given slide_number to a Cairo.ImageSurface and return it.
         *
         * If the requested slide is not available an
         * RenderError.SLIDE_DOES_NOT_EXIST error should be thrown.
         */
        public abstract Cairo.ImageSurface render_to_surface(int slide_number)
            throws RenderError;

        /**
         * Fill the display with black. Useful for last "slide" or for fading
         * to black at certain points in the presentation.
         */
        public abstract Cairo.ImageSurface fade_to_black();
    }

    /**
     * Error domain used for every render error, which might occur
     */
    public errordomain Renderer.RenderError {
        SLIDE_DOES_NOT_EXIST;
    }
}

