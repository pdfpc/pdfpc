/**
 * Presentation window
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

using Gtk;
using Gdk;

using org.westhoffswelt.pdfpresenter;

namespace org.westhoffswelt.pdfpresenter.Window {
    /**
     * Window showing the currently active slide to be presented on a beamer
     */
    public class Presentation: Fullscreen, Controllable {
        
        /**
         * Controller handling all the events which might happen. Furthermore it is
         * responsible to update all the needed visual stuff if needed
         */
        protected PresentationController presentation_controller = null;

        /**
         * EventBox with the Pdf image image in it, which will actually provide
         * the display of the presentation slide
         */
        protected PdfEventBox pdf_event_box;

        /**
         * Link handler used to handle pdf links
         */
        protected LinkHandler.Base link_handler = null;

        /**
         * Base constructor instantiating a new presentation window
         */
        public Presentation( string pdf_filename, int screen_num ) {
            base( screen_num );

            this.destroy += (source) => {
                Gtk.main_quit();
            };

            Color black;
            Color.parse( "black", out black );
            this.modify_bg( StateType.NORMAL, black );

            var fixedLayout = new Fixed();
            this.add( fixedLayout );

            this.pdf_event_box = new PdfEventBox.with_pdf_image( 
                new PdfImage.from_pdf( 
                    pdf_filename, 
                    0,
                    this.screen_geometry.width, 
                    this.screen_geometry.height,
                    !Options.disable_caching
                )
            );
            // Center the scaled pdf on the monitor
            // In most cases it will however fill the full screen
            fixedLayout.put(
                this.pdf_event_box,
                (int)Math.floor( ( this.screen_geometry.width - this.pdf_event_box.get_child().get_scaled_width() ) / 2.0 ),
                (int)Math.floor( ( this.screen_geometry.height - this.pdf_event_box.get_child().get_scaled_height() ) / 2.0 )
            );

            this.key_press_event += this.on_key_pressed;

            this.reset();
        }

        /**
         * Handle keypress events on the window and, if neccessary send them to the
         * presentation controller
         */
        protected bool on_key_pressed( Presentation source, EventKey key ) {
            if ( this.presentation_controller != null ) {
                this.presentation_controller.key_press( key );
            }
            return false;
        }

        /**
         * Set the presentation controller which is notified of keypresses and
         * other observed events
         */
        public void set_controller( PresentationController controller ) {
            this.presentation_controller = controller;

            // Register a new default link handler for the pdf_event_box and
            // connect it to the presentation controller.
            this.link_handler = new LinkHandler.Default( controller );
            this.link_handler.add( this.pdf_event_box );
        }

        /**
         * Switch the shown pdf to the next page
         */
        public void next_page() {
            this.pdf_event_box.get_child().next_page();
        }

        /**
         * Switch the shown pdf to the previous page
         */
        public void previous_page() {
            this.pdf_event_box.get_child().previous_page();
        }

        /**
         * Reset to the initial presentation state
         */
        public void reset() {
            try {
                this.pdf_event_box.get_child().goto_page( 0 );
            }
            catch( PdfImageError e ) {
                GLib.error( "The pdf page 0 could not be rendered: %s", e.message );
            }
        }

        /**
         * Display a specific page
         */
        public void goto_page( int page_number ) {
            try {
                this.pdf_event_box.get_child().goto_page( page_number );
            }
            catch( PdfImageError e ) {
                GLib.error( "The pdf page %d could not be rendered: %s", page_number, e.message );
            }
        }

        /**
         * Set the cache observer for the PdfImages on this window
         *
         * This method takes care of registering all PdfImages used by this window
         * correctly with the CacheStatus object to provide acurate cache status
         * measurements.
         */
        public void set_cache_observer( CacheStatus observer ) {
            observer.monitor_pdf_image( this.pdf_event_box.get_child() );
        }
    }
}
