/**
 * Default Pdf link handler
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

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Default link handler taking care of mousepointer changes, as well as
     * internal and launch links.
     */
    public class DefaultLinkHandler: LinkHandler {

        /**
         * Default constructor
         */
        public DefaultLinkHandler( PresentationController controller ) {
            base( controller );
        }

        /**
         * Register all the needed signal handlers for a newly added
         * PdfEventBox.
         */
        protected override void register_signals( PdfEventBox event_box ) {
            event_box.link_mouse_enter.connect( this.on_link_mouse_enter );
            event_box.link_mouse_leave.connect( this.on_link_mouse_leave );
            event_box.clicked_internal_link.connect( this.on_clicked_internal_link );
            event_box.clicked_external_command.connect( this.on_clicked_external_command );
        }

        /**
         * The mouse pointer has entered a pdf link
         */
        protected void on_link_mouse_enter( PdfEventBox source, Gdk.Rectangle link_rect, Poppler.LinkMapping mapping ) {
            // Set the cursor to the X11 theme default link cursor
            source.window.set_cursor( 
                new Cursor.from_name( 
                    Gdk.Display.get_default(),
                    "hand2"
                )
            );
        }

        /**
         * The mouse pointer has left a pdf link
         */
        protected void on_link_mouse_leave( PdfEventBox source, Gdk.Rectangle link_rect, Poppler.LinkMapping mapping ) {
            // Restore the cursor to its default state (The parent cursor
            // configuration is used)
            source.window.set_cursor( null );
        }

        /**
         * An internal link has been clicked
         */
        protected void on_clicked_internal_link( PdfEventBox source, Gdk.Rectangle link_rect, uint source_page_number, uint target_page_number ) {
            this.controller.page_change_request( (int)target_page_number );
        }

        /**
         * An external command link has been clicked
         */
        protected void on_clicked_external_command( PdfEventBox source, Gdk.Rectangle link_rect, uint source_page_number, string command, string arguments ) {
            //@TODO: Implement
        }
    }
}
