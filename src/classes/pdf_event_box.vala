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
        public signal void clicked_external_command( Gdk.Rectangle link_rect, uint source_page_number, string command );

        /**
         * Base constructor taking care of correct initialization
         */
        public PdfEventBox() {
            // Needed to handle link clicks correctly
            this.add_events( EventMask.BUTTON_RELEASE_MASK );
            this.button_release_event.connect( this.on_button_release );
        }

        /**
         * Convenience constructor to create an event box and attach a PdfImage
         * in one call.
         */
        public PdfEventBox.with_pdf_image( PdfImage pdf_image ) {
            this.add( pdf_image );

            // Needed to handle link clicks correctly
            this.add_events( EventMask.BUTTON_RELEASE_MASK );
            this.button_release_event.connect( this.on_button_release );
        }

        /**
         * Called whenever a mouse button is released inside the EventBox
         *
         * Maybe a link has been clicked. Therefore we need to handle this.
         */
        protected bool on_button_release( EventButton e ) {
            // If there is no child or we do not have a PdfImage as child we do
            // not need to do any further processing.
            if ( this.get_child() == null || !( this.get_child() is PdfImage ) ){
                return false;
            }

            // We are only interested in left button clicks
            if ( e.button != 1 ) {
                return false;
            }
          
            // In case the coords belong to a link we will get its action. If
            // they are pointing nowhere we just get null.
            LinkMapping mapping = this.get_link_mapping_by_coordinates( e.x, e.y );

            if ( mapping == null ) {
                return false;
            }

            // Handle the mapping properly by emitting the correct signals
            this.handle_link_mapping( mapping );

            // Call all registered callbacks up the chain as well.
            return false;
        }


        /**
         * Return the LinkMapping associated with link for the given
         * coordinates.
         *
         * If there is no link for the given coordinates null is returned
         * instead.
         */
        protected LinkMapping? get_link_mapping_by_coordinates( double x, double y ) {
            var child = this.get_child() as PdfImage;
            // Get the link mapping table
            Application.poppler_mutex.lock();
            var page = child.get_page();
            unowned GLib.List<unowned LinkMapping> link_mappings = page.get_link_mapping();
            Application.poppler_mutex.unlock();

            // We need to map projection space to pdf space, therefore we
            // normalize the coordinates
            int pdf_image_width;
            int pdf_image_height;
            child.get_size_request( out pdf_image_width, out pdf_image_height );
            double normalized_x = x / (double)pdf_image_width;
            double normalized_y = y / (double)pdf_image_height;
            
            // We need the page dimensions for coordinate conversion between
            // screen coordinates ((0,0) is in the upper left) and pdf
            // coordinates ((0,0) is in the bottom left). Furthermore they are
            // needed for normalization.
            double page_width;
            double page_height;
            Application.poppler_mutex.unlock();
            page.get_size( out page_width, out page_height );
            Application.poppler_mutex.unlock();

            // Try to find a matching link mapping on the page.
            LinkMapping result_mapping = null; 
            foreach( var mapping in link_mappings ) {
                // Normalize the x coordinates of the link area
                var normalized_area_x1 = mapping.area.x1 / page_width;
                var normalized_area_x2 = mapping.area.x2 / page_width;

                // Normalize and transform the y area coordinates from pdf to
                // screen space. 
                // To allow for a clean mapping we need to "flip" the
                // coordinates as well as subtract them from the page height.
                var normalized_area_y1 = ( page_height - mapping.area.y2 ) / page_height;
                var normalized_area_y2 = ( page_height - mapping.area.y1 ) / page_height;

                // A simple bounding box check tells us if the given point lies
                // within the link area.
                if ( ( normalized_x >= normalized_area_x1 )
                  && ( normalized_x <= normalized_area_x2 )
                  && ( normalized_y >= normalized_area_y1 )
                  && ( normalized_y <= normalized_area_y2 ) ) {
                    result_mapping = mapping.copy();
                    break;
                }
            }

            // Free the allocated mapping structure
            Application.poppler_mutex.lock();
            page.free_link_mapping( link_mappings );
            Application.poppler_mutex.unlock();

            return result_mapping;
        }
    
        /**
         * Handle the given mapping as it has been clicked on.
         *
         * This method evaluates the mapping and emits all signals which are
         * needed in the given case.
         */
        protected void handle_link_mapping( LinkMapping mapping ) {
            //@TODO: Implement
        }
    }
}
