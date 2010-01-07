/**
 * Signal deecoration interface
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
     * Every object implementing this interface does support to be decorated
     * with further signals
     */
    public interface SignalDecoratable: GLib.Object {
        /**
         * Register the given signal decorator to provide its signals
         */
        public abstract void decorate_signals( SignalDecorator.Base decorator );

        /**
         * Get the signals of a certain decorator
         */
        public abstract SignalDecorator.Base get_signals( string decorator_group );
    }
}
