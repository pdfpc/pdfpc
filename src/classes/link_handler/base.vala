/**
 * Pdf link handler interface
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

namespace org.westhoffswelt.pdfpresenter.LinkHandler {
    /**
     * Abstract class interface to be implemented by every link handler
     *
     * A link handler is supposed to handle all link based events of the
     * PdfEventBox and react on them properly.
     */
    public abstract class Base: Object {
        /**
         * All known and handled PdfEventBoxes
         */
        protected List<PdfEventBox> event_boxes = new List<PdfEventBox>();

        /**
         * Presentation controller queried to handle the appropriate link
         * actions
         */
        protected PresentationController controller = null;

        /**
         * Constructor taking the main PresentationController as an argument
         */
        public Base( PresentationController controller ) {
            this.controller = controller;
        }

        /**
         * Add a PdfEventBox to the link handler
         *
         * The link handler takes care of handling all the link specific stuff
         * for this eventbox afterwards.
         */
        public void add( PdfEventBox event_box ) {
            this.event_boxes.append( event_box );
            this.register_signals( event_box );
        }

        /**
         * Register all the needed signal handlers for the new PdfEventBox.
         */
        protected abstract void register_signals( PdfEventBox event_box );
    }
}
