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
        public Engine( Metadata.Base metadata ) {
            base( metadata );
            if( this.storage.length == 0 ) {
                this.storage = new Cairo.ImageSurface[this.metadata.get_slide_count()];
            }
        }

        /**
         * Store a surface in the cache using the given index as identifier
         */
        public override void store( uint index, Cairo.ImageSurface surface ) {
            cache_update_required = true;
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

        /**
         * Store the cache to disk
         */
        public override void persist(DataOutputStream cache) throws Error {
            cache.put_int32(0); /* Mark this as a version 1 cache for the simple engine */
            cache.put_int32(this.storage.length);
            for(var i=0; i<this.storage.length; i++) {
                cache.put_int32(this.storage[i].get_format());
                cache.put_int32(this.storage[i].get_width());
                cache.put_int32(this.storage[i].get_height());
                cache.put_int32(this.storage[i].get_stride());

                this.storage[i].flush();
                unowned uchar[] image_data = this.storage[i].get_data();

                /* TODO For some reason, image_data.length is always zero, so
                 * caching does not work yet for the simple cache. */

                cache.put_uint32(image_data.length);
                cache.write(image_data);
            }

            cache.flush();
        }

        /**
         * Load the cache from disk
         */
        public override void load_from_disk(DataInputStream cache) throws Error {
            if(cache.read_int32() != 0) {
                error("Invalid cache file.");
            }
            var length = cache.read_int32();
            for(var i=0; i<length; i++) {
                var format = cache.read_int32();
                var width = cache.read_int32();
                var height = cache.read_int32();
                var stride = cache.read_int32();
                var data_length = cache.read_uint32();

                uint8[] data = new uint8[data_length];
                cache.read(data);

                this.storage[i] = new Cairo.ImageSurface.for_data(data, (Cairo.Format) format, width, height, stride);
            }
        }
    }
}
