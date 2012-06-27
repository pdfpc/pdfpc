/**
 * Caching interface
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

namespace pdfpc.Renderer {
    /**
     * Every renderer may decide to implement the Caching interface to improve
     * rendering speed.
     */
    public interface Caching: GLib.Object {
        /**
         * Set a Cache store to be used for caching
         */
        public abstract void set_cache( Cache.Base cache );

        /**
         * Retrieve the currently used cache store
         *
         * If no cache store is set null will be returned.
         */
        public abstract Cache.Base get_cache();
    }
}
