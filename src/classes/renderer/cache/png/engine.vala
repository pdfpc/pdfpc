/**
 * PNG cache store
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
     * Cache store which holds all given items in memory as compressed png
     * images
     */
    public class PNG.Engine: Renderer.Cache.Base {
        /**
         * In memory storage for all the given pixmaps
         */
        protected PNG.Item[] storage = null;

        /**
         * Initialize the cache store
         */
        public Engine( Metadata.Pdf metadata ) {
            base( metadata );
            this.storage = new PNG.Item[this.metadata.get_slide_count()];
        }

        /**
         * Store a surface in the cache using the given index as identifier
         */
        public override void store( uint index, Cairo.ImageSurface surface ) {
            png_store(index, surface);
        }

        protected void png_store(uint index, Cairo.ImageSurface surface ) {
            int buffer_length = surface.get_stride()*surface.get_height();
            unowned uchar[] buffer = surface.get_data();
            uchar[] buffer_copy = buffer[0:buffer_length];

            var item = new PNG.Item();
            item.data = buffer_copy;
            item.width = surface.get_width();
            item.height = surface.get_height();

            this.storage[index] = item;
        }

        /**
         * Retrieve a stored surface from the cache.
         *
         * If no item with the given index is available null is returned
         */
        public override Cairo.ImageSurface? retrieve( uint index ) {
            return png_retrieve(index);
        }

        protected Cairo.ImageSurface? png_retrieve( uint index ) {
            var item = this.storage[index];
            if ( item == null ) {
                return null;
            }

            Cairo.ImageSurface surface = new Cairo.ImageSurface.for_data(
                item.data, Cairo.Format.RGB24, item.width, item.height,
                Cairo.Format.RGB24.stride_for_width(item.width)
            );

            return surface;
        }
    }
}

