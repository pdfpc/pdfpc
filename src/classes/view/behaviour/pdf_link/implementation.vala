/**
 * Pdf link handling Behaviour
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

namespace org.westhoffswelt.pdfpresenter.View.Behaviour {
    /**
     * Behaviour which handles links inside of Pdf based Views
     */
    public class PdfLink.Implementation: Base {
        /**
         * SignalProvider creating all the needed events to handle pdf links
         * nicely.
         */
        protected PdfLink.SignalProvider signal_provider = null;

        /**
         * Base constructor not taking any arguments
         */
        public Implementation() {
            base();
            // Make sure a PdfLink.SignalProvider is ready to create the needed
            // pdf link based signals.
            this.signal_provider = new PdfLink.SignalProvider();
        }        

        /**
         * Associate the implementing Behaviour with the given View
         * 
         * This method will register a lot of new signals on the target to
         * handle all the different states.
         */
        public override void associate( View.Base target )
            throws AssociationError {            
            this.enforce_exclusive_association( target );
            this.target = target;

            // Attach the View to the SignalProvider
            this.signal_provider.attach( target as View.Pdf );

            // Register to all the needed signals on the SignalProvider
            this.signal_provider.link_mouse_enter.connect( 
                this.on_link_mouse_enter
            );
            this.signal_provider.link_mouse_leave.connect(
                this.on_link_mouse_leave
            );
            this.signal_provider.clicked_internal_link.connect(
                this.on_clicked_internal_link
            );
            this.signal_provider.clicked_external_command.connect(
                this.on_clicked_external_command
            );
        }

        /**
         * Check wheter the given target is supported by this Behaviour
         *
         * Only View.Pdf and its descendants are allowed to be used in
         * conjunction with this Behaviour
         */
        protected new bool is_supported( View.Base target ) {
            return ( target is View.Pdf );
        }

        /**
         * The mouse pointer has entered a pdf link
         */
        protected void on_link_mouse_enter( Gdk.Rectangle link_rect, Poppler.LinkMapping mapping ) {
            // Set the cursor to the X11 theme default link cursor
            this.target.window.set_cursor( 
                new Gdk.Cursor.from_name( 
                    Gdk.Display.get_default(),
                    "hand2"
                )
            );
        }

        /**
         * The mouse pointer has left a pdf link
         */
        protected void on_link_mouse_leave( Gdk.Rectangle link_rect, Poppler.LinkMapping mapping ) {
            // Restore the cursor to its default state (The parent cursor
            // configuration is used)
            this.target.window.set_cursor( null );
        }

        /**
         * An internal link has been clicked
         */
        protected void on_clicked_internal_link( Gdk.Rectangle link_rect, uint source_page_number, uint target_page_number ) {
            // @TODO: Think of something different to access the controller
            // instead of this ugly HACK. Maybe the whole controller concept as
            // it is implemented right now should be reconsidered.
            var window = this.target.get_parent().get_parent();
            ((Controllable)window).get_controller().page_change_request( 
                (int)target_page_number
            );
        }

        /**
         * An external command link has been clicked
         */
        protected void on_clicked_external_command( Gdk.Rectangle link_rect, uint source_page_number, string command, string arguments ) {
            //@TODO: Implement
        }
    }
}
