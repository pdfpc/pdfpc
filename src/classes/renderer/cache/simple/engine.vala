/**
 * Simple cache store
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
using Gdk;

using org.westhoffswelt.pdfpresenter;

namespace org.westhoffswelt.pdfpresenter.Renderer.Cache {
    /**
     * Cache store which simply holds all given items in memory.
     */
    public class Simple.Engine: Renderer.Cache.Base {
        /**
         * In memory storage for all the given pixmaps
         */
        protected Pixmap[] storage = null;

        /**
         * Mutex used to limit access to storage array to one thread at a time.
         *
         * Unfortunately the vala lock statement does not work here.
         */
        protected Mutex mutex = new Mutex();

        /**
         * Initialize the cache store
         */
        public Engine( Metadata.Base metadata ) {
            base( metadata );

            this.mutex.lock();
            this.storage = new Pixmap[this.metadata.get_slide_count()];
            this.mutex.unlock();
        }

        /**
         * Store a pixmap in the cache using the given index as identifier
         */
        public override void store( uint index, Pixmap pixmap ) {
            this.mutex.lock();
            this.storage[index] = pixmap;
            this.mutex.unlock();
        }

        /**
         * Retrieve a stored pixmap from the cache.
         *
         * If no item with the given index is available null is returned
         */
        public override Pixmap? retrieve( uint index ) {
            return this.storage[index];
        }
    }
}
