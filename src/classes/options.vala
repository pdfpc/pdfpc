/**
 * Application wide options
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

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Static property container holding the application wide option
     * information and their default values.
     */
    public class Options: GLib.Object {
        /**
         * Commandline option specifying if the presenter and presentation screen
         * should be switched.
         */
        public static bool display_switch = false;
        
        /**
         * Commandline option which allows the complete disabling of slide caching
         */
        public static bool disable_caching = false;

        /**
         * Commandline option to enable the compression of cached slides. This
         * trades speed for memory. A lot of memory ;) It's about factor 30
         * smaller for normal presentations.
         */
        public static bool enable_cache_compression = false;

        /**
         * Commandline option providing the talk duration, which will be used to
         * display a timer
         */
        public static uint duration = 45;

        /**
         * Commandline option providing the time from which on the timer should
         * change its color.
         */
        public static uint last_minutes = 5;

        /**
         * Commandline option providing the size of the current slide in
         * the presenter window
         */
        public static uint current_size = 60;
    }
}
