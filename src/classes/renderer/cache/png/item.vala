/**
 * PNG Cache engine item
 *
 * This file is part of pdf-presenter-console.
 *
 * pdf-presenter-console is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3 of the License.
 *
 * pdf-presenter-console is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * pdf-presenter-console; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

using GLib;

namespace org.westhoffswelt.pdfpresenter.Renderer.Cache {
    /**
     * PNG picture data stored by the PNG cache engine.
     */
    public class PNG.Item: Object {
        /**
         * PNG picture data stored for this item
         */
        protected uchar[] data;

        /**
         * Create the item from a uchar array
         */
        public Item( uchar[] data ) {
            this.data = data;
        }

        /**
         * Create the item from a char array
         */
        public Item.with_char_array( char[] data ) {
            this( (uchar[]) data );
        }

        /**
         * Return the stored data
         */
        public uchar[] get_png_data() {
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
