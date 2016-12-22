/**
 * Cache store
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
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

namespace pdfpc.Renderer.Cache {
    /**
     * Base Cache store interface which needs to be implemented by every
     * working cache.
     */
    public abstract class Base : Object {
        /**
         * Metadata object to provide caching for
         */
        protected Metadata.Pdf metadata;

        /**
         * Initialize the cache store
         */
        public Base(Metadata.Pdf metadata) {
            this.metadata = metadata;
        }

        /**
         * Asks the cache engine if prerendering is allowed in conjunction with it.
         *
         * The default behaviour is to allow prerendering, there might however
         * be engine implementation where prerendering does not make any sense.
         * Therefore it can be disabled by overriding this method and returning
         * false.
         */
        public bool allows_prerendering() {
            return true;
        }

        /**
         * Store a surface in the cache using the given index as identifier
         */
        public abstract void store(uint index, Cairo.ImageSurface surface);

        /**
         * Retrieve a stored surface from the cache.
         *
         * If no item with the given index is available null is returned
         */
        public abstract Cairo.ImageSurface? retrieve(uint index);
    }

    /**
     * Creates cache engines based on the global commandline options
     */
    public Base create(Metadata.Pdf metadata) {
        if (Options.persist_cache) {
            return new PNG.Persistent.Engine(metadata);
        }

        if (!Options.disable_cache_compression) {
            return new PNG.Engine(metadata);
        }

        return new Simple.Engine(metadata);
    }
}
