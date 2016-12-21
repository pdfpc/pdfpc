/**
 * Simple cache store
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
 * Copyright 2015 Andreas Bilke
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

namespace pdfpc.Renderer.Cache {
    /**
     * Cache store which simply holds all given items in memory.
     */
    public class Simple.Engine: Renderer.Cache.Base {
        /**
         * In memory storage for all the given surfaces
         */
        protected Cairo.ImageSurface[] storage = null;

        /**
         * Initialize the cache store
         */
        public Engine( Metadata.Pdf metadata ) {
            base( metadata );
            this.storage = new Cairo.ImageSurface[this.metadata.get_slide_count()];
        }

        /**
         * Store a surface in the cache using the given index as identifier
         */
        public override void store( uint index, Cairo.ImageSurface surface ) {
            this.storage[index] = surface;
        }

        /**
         * Retrieve a stored pixmap from the cache.
         *
         * If no item with the given index is available null is returned
         */
        public override Cairo.ImageSurface? retrieve( uint index ) {
            return this.storage[index];
        }
    }
}
