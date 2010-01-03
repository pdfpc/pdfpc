/**
 * Pdf Event box
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
using Poppler;

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Gtk EventBox enhanced with certain signals which may be needed from
     * PdfImage objects.
     * 
     * In addition to the usual EventBox signals this container emits signals
     * for events like clicked links in pdf documents, which might then be
     * handled further.
     */
    public class PdfEventBox: Gtk.EventBox {
        /**
         * Emitted whenever a link on a pdf page is clicked, which should
         * trigger a document internal switch to another page.
         */
        public signal void clicked_internal_link( Gdk.Rectangle link_rect, uint source_page_number, uint target_page_number );

        /**
         * Emitted whenever a link on a pdf page is clicked, which should
         * execute an external command.
         *
         * Be careful while handling these, as requested code to be execute may
         * be malicious.
         */
        public signal void clicked_external_command( Gdk.Rectangle link_rect, uint source_page_number, string command, string arguments );

        /**
         * Emitted whenever the mouse entered a pdf link
         */
        public signal void link_mouse_enter( Gdk.Rectangle link_rect, Poppler.LinkMapping mapping );

        /**
         * Emitted whenever the mouse left a pdf link
         */
        public signal void link_mouse_leave( Gdk.Rectangle link_rect, Poppler.LinkMapping mapping );

        /**
         * The LinkMapping which is currently beneath the mouse cursor or null
         * if there is none.
         */
        protected LinkMapping active_mapping = null;

        /**
         * LinkMappings of the current page
         */
        protected unowned GLib.List<unowned LinkMapping> page_link_mappings = null;

        /**
         * Precalculated Gdk.Rectangles for every link mapping
         */
        protected Gdk.Rectangle[] precalculated_mapping_rectangles = null;

        /**
         * Base constructor taking care of correct initialization
         */
        public PdfEventBox() {
            // Needed to handle link clicks correctly
            this.add_events( EventMask.BUTTON_RELEASE_MASK );
            this.button_release_event.connect( this.on_button_release );

            this.add_events( EventMask.POINTER_MOTION_MASK );
            this.motion_notify_event += this.on_mouse_move;
        }

        /**
         * Convenience constructor to create an event box and attach a PdfImage
         * in one call.
         */
        public PdfEventBox.with_pdf_image( PdfImage pdf_image ) {
            // Needed to handle link clicks correctly
            this.add_events( EventMask.BUTTON_RELEASE_MASK );
            this.button_release_event.connect( this.on_button_release );
            
            this.add_events( EventMask.POINTER_MOTION_MASK );
            this.motion_notify_event.connect( this.on_mouse_move );

            this.add( pdf_image );
        }

        /**
         * Add a PdfImage as child of this EventBox
         *
         * Overridden to only accept PdfImage objects
         */
        public new void add( PdfImage pdf_image ) {
            if ( this.get_child() != null ) {
                return;
            }

            base.add( pdf_image );

            // Monitor page transitions to handle the link mappings correctly.
            pdf_image.page_entered.connect( this.on_page_entered );
            pdf_image.page_leaving.connect( this.on_page_leaving );
        }

        /**
         * Return the PdfImage associated with this EventBox.
         *
         * Overridden to return correctly casted PdfImage object.
         */
        public new PdfImage get_child() {
            return base.get_child() as PdfImage;
        }

        /**
         * Called whenever a mouse button is released inside the EventBox
         *
         * Maybe a link has been clicked. Therefore we need to handle this.
         */
        protected bool on_button_release( EventButton e ) {
            // If there is no child we do not need to do any further
            // processing.
            if ( this.get_child() == null ){
                return false;
            }

            // We are only interested in left button clicks
            if ( e.button != 1 ) {
                return false;
            }
          
            // In case the coords belong to a link we will get its action. If
            // they are pointing nowhere we just get null.
            unowned LinkMapping mapping = this.get_link_mapping_by_coordinates( e.x, e.y );

            if ( mapping == null ) {
                return false;
            }

            // Handle the mapping properly by emitting the correct signals
            this.handle_link_mapping( mapping );

            // Call all registered callbacks up the chain as well.
            return false;
        }

        /**
         * Called whenever the mouse is moved on the surface of the widget
         *
         * This method changes the mouse cursor if the pointer enters or leaves
         * a link
         */
        protected bool on_mouse_move( EventMotion event ) {
            unowned LinkMapping link_mapping = this.get_link_mapping_by_coordinates( event.x, event.y );

            if ( link_mapping == null ) {
                // We may have left a link
                if ( this.active_mapping != null ) {
                    this.link_mouse_leave( 
                        this.convert_poppler_rectangle_to_gdk_rectangle( this.active_mapping.area ),
                        this.active_mapping
                    );
                    this.active_mapping = null;
                }
                return false;
            }

            if ( link_mapping != null && link_mapping == this.active_mapping ) {
                // We are still inside the current active link
                // Therefore we do nothing
                return false;
            }

            if ( link_mapping != null && this.active_mapping == null ) {
                // We just entered a new link
                this.active_mapping = link_mapping.copy();
                this.link_mouse_enter( 
                    this.convert_poppler_rectangle_to_gdk_rectangle( this.active_mapping.area ),
                    this.active_mapping
                );
                return false;
            }

            // We "jumped" from one link to another. Therefore enter and leave signals are needed.
            this.link_mouse_leave( 
                this.convert_poppler_rectangle_to_gdk_rectangle( this.active_mapping.area ),
                this.active_mapping
            );
            this.active_mapping = link_mapping.copy();
            this.link_mouse_enter( 
                this.convert_poppler_rectangle_to_gdk_rectangle( this.active_mapping.area ),
                this.active_mapping
            );
            return false;
        }

        /**
         * Handle newly entered pdf pages to create a link mapping table for
         * further requests and checks.
         */
        public void on_page_entered( uint page_number ) {
            // Get the link mapping table
            Application.poppler_mutex.lock();
            var page = this.get_child().get_page();
            this.page_link_mappings = page.get_link_mapping();
            Application.poppler_mutex.unlock();

            // Precalculate the a Gdk.Rectangle for every link mapping area
            if ( this.page_link_mappings.length() > 0 ) {
                this.precalculated_mapping_rectangles = new Gdk.Rectangle[this.page_link_mappings.length()];
                int i=0;
                foreach( var mapping in this.page_link_mappings ) {
                    this.precalculated_mapping_rectangles[i++] = this.convert_poppler_rectangle_to_gdk_rectangle( 
                        mapping.area
                    );
                }
            }
        }

        /**
         * Free the allocated link mapping tables, which were created on page
         * entering
         */
        public void on_page_leaving( uint from, uint to ) {
            // Free memory of precalculated rectangles
            this.precalculated_mapping_rectangles = null;

            // Free the mapping memory
            Application.poppler_mutex.lock();
            Poppler.Page.free_link_mapping(  
                this.page_link_mappings
            );
            Application.poppler_mutex.unlock();
        }

        /**
         * Return the LinkMapping associated with link for the given
         * coordinates.
         *
         * If there is no link for the given coordinates null is returned
         * instead.
         */
        protected unowned LinkMapping? get_link_mapping_by_coordinates( double x, double y ) {
            // Try to find a matching link mapping on the page.
            for( var i=0; i<this.precalculated_mapping_rectangles.length; ++i ) {
                Gdk.Rectangle r = this.precalculated_mapping_rectangles[i];
                // A simple bounding box check tells us if the given point lies
                // within the link area.
                if ( ( x >= r.x )
                  && ( x <= r.x + r.width )
                  && ( y >= r.y )
                  && ( y <= r.y + r.height ) ) {
                    return this.page_link_mappings.nth_data( i );
                }
            }
            return null;
        }
    
        /**
         * Handle the given mapping as it has been clicked on.
         *
         * This method evaluates the mapping and emits all signals which are
         * needed in the given case.
         */
        protected void handle_link_mapping( LinkMapping mapping ) {
            switch( mapping.action.type ) {
                // Internal goto link
                case ActionType.GOTO_DEST:
                    // There are different goto destination types we need to
                    // handle correctly.
                    unowned ActionGotoDest action = (ActionGotoDest)mapping.action;
                    switch( action.dest.type ) {
                        case DestType.NAMED:
                            Application.poppler_mutex.lock();
                            var document = this.get_child().get_document();
                            unowned Poppler.Dest destination = document.find_dest( 
                                action.dest.named_dest
                            );
                            Application.poppler_mutex.unlock();

                            // Fire the correct signal for this
                            this.clicked_internal_link( 
                                this.convert_poppler_rectangle_to_gdk_rectangle( mapping.area ),
                                this.get_child().get_page_number(),
                                /* We use zero based indexing. Pdf links use one based indexing */ 
                                destination.page_num - 1
                            );
                        break;
                    }
                break;
                // External launch link
                case ActionType.LAUNCH:
                    unowned ActionLaunch action = (ActionLaunch)mapping.action;
                    // Fire the appropriate signal
                    this.clicked_external_command( 
                        this.convert_poppler_rectangle_to_gdk_rectangle( mapping.area ),
                        this.get_child().get_page_number(),
                        action.file_name,
                        action.params
                    );
                break;
            }
        }

        /**
         * Convert an arbitrary Poppler.Rectangle struct into a Gdk.Rectangle
         * struct taking into account the measurement differences between pdf
         * space and screen space.
         */
        protected Gdk.Rectangle convert_poppler_rectangle_to_gdk_rectangle( Poppler.Rectangle poppler_rectangle ) {
            Gdk.Rectangle gdk_rectangle = Gdk.Rectangle();

            Gtk.Requisition requisition;
            this.get_child().size_request( out requisition );

            // We need the page dimensions for coordinate conversion between
            // pdf coordinates and screen coordinates
            double page_width;
            double page_height;
            Application.poppler_mutex.lock();
            this.get_child().get_page().get_size( out page_width, out page_height );
            Application.poppler_mutex.unlock();

            gdk_rectangle.x = (int)Math.ceil( ( poppler_rectangle.x1 / page_width ) * requisition.width );
            gdk_rectangle.width = (int)Math.floor( ( ( poppler_rectangle.x2 - poppler_rectangle.x1 ) / page_width ) * requisition.width );

            // Gdk has its coordinate origin in the upper left, while Poppler
            // has its origin in the lower left.
            gdk_rectangle.y = (int)Math.ceil( ( ( page_height - poppler_rectangle.y2 ) / page_height ) * requisition.height );
            gdk_rectangle.height = (int)Math.floor( ( ( poppler_rectangle.y2 - poppler_rectangle.y1 ) / page_height ) * requisition.height );

            return gdk_rectangle;
        }
    }
}
