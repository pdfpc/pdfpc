/**
 * Option based Cache-Engine factory
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

using GLib;

using pdfpc;

namespace pdfpc.Renderer {
    /**
     * Creates cache engines based on the global commandline options
     */
    public class Cache.OptionFactory: Object {

        /**
         * Do not allow instantiation of the factory
         */
        private OptionFactory() {
            // Nothing to do just keep the constructor private
        }

        /**
         * Create and return a new Cache engine based on the set of commandline
         * options.
         */
        public static Cache.Base create( Metadata.Base metadata ) {
            if ( !Options.disable_cache_compression ) {
                return new Cache.PNG.Engine( metadata );
            }
            else {
                return new Cache.Simple.Engine( metadata );
            }
        }
    }
}
