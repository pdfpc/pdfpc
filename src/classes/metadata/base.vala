/**
 * Slide metadata information
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
     * Metadata base class describing the basic metadata needed for every
     * slideset
     */
    public abstract class Metadata.Base: Object
    {
        /**
         * Unique Resource Locator for the given slideset
         */
        protected string url;

        /**
         * Base constructor taking the url to specifiy the slideset as argument
         */
        public Base( string url ) {
            this.url = url;
        }

        /**
         * Return the registered url
         */
        public string get_url() {
            return this.url;
        }

        /**
         * Return the number of slides defined by the given url
         */
        public abstract uint get_slide_count();
    }
}
