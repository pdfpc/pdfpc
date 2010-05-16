/**
 * Slide renderer
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
     * Renderer base class needed to be extended by every slide renderer.
     */
    public abstract class Renderer.Base: Object
    {
        /**
         * Metadata object to render slides for
         */
        protected Metadata.Base metadata;

        /**
         * Width to render to
         */
        protected int width;

        /**
         * Height to render to
         */
        protected int height;

        /**
         * Base constructor taking a metadata object as well as the desired
         * render width and height as parameters.
         */
        public Base( Metadata.Base metadata, int width, int height ) {
            this.metadata = metadata;
            this.width = width;
            this.height = height;
        }

        /**
         * Return the registered metadata object
         */
        public Metadata.Base get_metadata() {
            return this.metadata;
        }

        /**
         * Return the desired render width
         */
        public int get_width() {
            return this.width;
        }

        /**
         * Return the desired render height
         */
        public int get_height() {
            return this.height;
        }

        /**
         * Render the given slide_number to a Gdk.Pixmap and return it.
         *
         * If the requested slide is not available an
         * RenderError.SLIDE_DOES_NOT_EXIST error should be thrown.
         */
        public abstract Gdk.Pixmap render_to_pixmap( int slide_number ) 
            throws RenderError;
    }

    /**
     * Error domain used for every render error, which might occur
     */
    errordomain Renderer.RenderError {
        SLIDE_DOES_NOT_EXIST;
    }
}
