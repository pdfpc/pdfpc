/**
 * PNG Cache engine item
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

namespace pdfpc.Renderer.Cache {
    /**
     * PNG picture data stored by the PNG cache engine.
     */
    public class PNG.Item: Object {
        /**
         * PNG picture data stored for this item
         */
        protected uint8[] data;

        /**
         * Create the item from a uchar array
         */
        public Item( uint8[] data ) {
            this.data = data;
        }

        /**
         * Return the stored data
         */
        public uint8[] get_png_data() {
            return this.data;
        }

        /**
         * Shortcut to retrieve the length of the stored dataset
         */
        public int get_length() {
            return this.data.length;
        }
    }
}
