/**
 * Option based Cache-Engine factory
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

using org.westhoffswelt.pdfpresenter;

namespace org.westhoffswelt.pdfpresenter.Renderer {
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
            if ( Options.enable_cache_compression ) {
                return new Cache.PNG.Engine( metadata );
            }
            else {
                return new Cache.Simple.Engine( metadata );
            }
        }
    }
}
