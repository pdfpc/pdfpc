/**
 * Application wide mutex locks
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

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Static property container holding all mutex locks, which are needed
     * throughout the application.
     */
    public class MutexLocks: Object {
       /**
        * Lock which needs to be used every time poppler is used.
        *
        * Unfortunately the poppler library is not threadsafe.
        */
       public static Mutex poppler;

        /**
         * Initialize all used mutex objects for the first time
         */
       public static void init() {
           MutexLocks.poppler = new Mutex();
       }
    }
}
