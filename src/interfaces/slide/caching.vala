/**
 * Caching interface
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

namespace org.westhoffswelt.pdfpresenter.Slide {
    /**
     * Every renderer may decide to implement the Caching interface for speed
     * enhancements.
     *
     * To be able to control and query these rendering specific methods a
     * unified interface needs to exist.
     */
    public interface Caching: GLib.Object {
        /**
         * Signal emitted every time a precached slide has been created
         *
         * This signal should be emitted slide_count number of times during a
         * precaching cylce.
         */
        public abstract signal void slide_precached();

        /**
         * Signal emitted when the precaching cycle is complete
         */
        public abstract signal void precaching_completed();

        /**
         * Signal emitted when the precaching cycle just started
         */
        public abstract signal void precaching_started();

        /**
         * Enable the caching and initialize it. If precaching should be done
         * this method will mostlikely start the precaching thread.
         */
        public abstract void enable_caching( bool precaching = false );
    }
}
