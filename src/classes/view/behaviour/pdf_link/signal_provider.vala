/**
 * Signal Provider for all pdf link related events
 *
 * This file is part of pdf-presenter-console.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

using GLib;

using org.westhoffswelt.pdfpresenter;

namespace org.westhoffswelt.pdfpresenter.View.Behaviour {
    /**
     * Access provider to all signals related to PDF links.
     */
    public class PdfLink.SignalProvider: Object {
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
         * View which is attached to this provider
         */
        protected View.Pdf target = null;

        /**
         * The Poppler.LinkMapping which is currently beneath the mouse cursor or null
         * if there is none.
         */
        protected Poppler.LinkMapping active_mapping = null;

        /**
         * Poppler.LinkMappings of the current page
         */
        //protected unowned GLib.List<unowned Poppler.LinkMapping> page_link_mappings = null;
        protected GLib.List<Poppler.LinkMapping> page_link_mappings = null;

        /**
         * Precalculated Gdk.Rectangles for every link mapping
         */
        protected Gdk.Rectangle[] precalculated_mapping_rectangles = null;
        
        /**
         * Attach a View.Pdf to this signal provider
         */
        public void attach( View.Pdf view ) {
            this.target = view;

            view.add_events( Gdk.EventMask.BUTTON_PRESS_MASK );
            view.add_events( Gdk.EventMask.POINTER_MOTION_MASK );

            view.button_press_event.connect( this.on_button_press );
            view.motion_notify_event.connect( this.on_mouse_move );
            view.entering_slide.connect( this.on_entering_slide );
            view.leaving_slide.connect( this.on_leaving_slide );
        }

        /**
         * Return the Poppler.LinkMapping associated with link for the given
         * coordinates.
         *
         * If there is no link for the given coordinates null is returned
         * instead.
         */
        protected unowned Poppler.LinkMapping? get_link_mapping_by_coordinates( double x, double y ) {
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
        protected void handle_link_mapping( Poppler.LinkMapping mapping ) {
            switch( mapping.action.type ) {
                // Internal goto link
                case Poppler.ActionType.GOTO_DEST:
                    // There are different goto destination types we need to
                    // handle correctly.
                    unowned Poppler.ActionGotoDest* action = (Poppler.ActionGotoDest*)mapping.action;
                    switch( action.dest.type ) {
                        case Poppler.DestType.NAMED:
                            MutexLocks.poppler.lock();
                            var metadata = this.target.get_renderer().get_metadata() as Metadata.Pdf;
                            var document = metadata.get_document();
                            //unowned Poppler.Dest destination;
                            //destination = document.find_dest(
                            Poppler.Dest destination = document.find_dest( 
                                action.dest.named_dest
                            );
                            MutexLocks.poppler.unlock();

                            // Fire the correct signal for this
                            this.clicked_internal_link( 
                                this.convert_poppler_rectangle_to_gdk_rectangle( mapping.area ),
                                this.target.get_current_slide_number(),
                                /* We use zero based indexing. Pdf links use one based indexing */ 
                                destination.page_num - 1
                            );
                        break;
                    }
                break;
                // External launch link
                case Poppler.ActionType.LAUNCH:
                    unowned Poppler.ActionLaunch* action = (Poppler.ActionLaunch*)mapping.action;
                    // Fire the appropriate signal
                    this.clicked_external_command( 
                        this.convert_poppler_rectangle_to_gdk_rectangle( mapping.area ),
                        this.target.get_current_slide_number(),
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
            this.target.size_request( out requisition );

            // We need the page dimensions for coordinate conversion between
            // pdf coordinates and screen coordinates
            var metadata = this.target.get_renderer().get_metadata() as Metadata.Pdf;
            gdk_rectangle.x = (int)Math.ceil( ( poppler_rectangle.x1 / metadata.get_page_width() ) * requisition.width );
            gdk_rectangle.width = (int)Math.floor( ( ( poppler_rectangle.x2 - poppler_rectangle.x1 ) / metadata.get_page_height() ) * requisition.width );

            // Gdk has its coordinate origin in the upper left, while Poppler
            // has its origin in the lower left.
            gdk_rectangle.y = (int)Math.ceil( ( ( metadata.get_page_height() - poppler_rectangle.y2 ) / metadata.get_page_height() ) * requisition.height );
            gdk_rectangle.height = (int)Math.floor( ( ( poppler_rectangle.y2 - poppler_rectangle.y1 ) / metadata.get_page_height() ) * requisition.height );

            return gdk_rectangle;
        }

        /**
         * Called whenever a mouse button is pressed inside the View.Pdf
         *
         * Maybe a link has been clicked. Therefore we need to handle this.
         */
        protected bool on_button_press( Gtk.Widget source, Gdk.EventButton e ) {
            // We are only interested in left button clicks
            if ( e.button != 1 ) {
                return false;
            }
          
            // In case the coords belong to a link we will get its action. If
            // they are pointing nowhere we just get null.
            unowned Poppler.LinkMapping mapping = this.get_link_mapping_by_coordinates( e.x, e.y );

            if ( mapping == null ) {
                return false;
            }

            // Handle the mapping properly by emitting the correct signals
            this.handle_link_mapping( mapping );
            
            // Other callbacks up the chain are suppressed to make sure nobody
            // else changes the presentation page on a mouseclick.
            return true;
        }

        /**
         * Called whenever the mouse is moved on the surface of the View.Pdf
         *
         * The signal emitted by this method may for example be used to change
         * the mouse cursor if the pointer enters or leaves a link
         */
        protected bool on_mouse_move( Gtk.Widget source, Gdk.EventMotion event ) {
            unowned Poppler.LinkMapping link_mapping = this.get_link_mapping_by_coordinates( event.x, event.y );

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
        public void on_entering_slide( View.Base source, int page_number ) {
            // Get the link mapping table
            bool in_range = true;
            MutexLocks.poppler.lock();
            Metadata.Pdf metadata = source.get_renderer().get_metadata() as Metadata.Pdf;
            if (page_number < metadata.get_slide_count()) {
                Poppler.Page page = metadata.get_document().get_page( page_number );
                this.page_link_mappings = page.get_link_mapping();
            } else {
                this.page_link_mappings = null;
                in_range = false;
            }
            MutexLocks.poppler.unlock();
            if (!in_range)
                return;

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
        public void on_leaving_slide( View.Base source, int from, int to ) {
            // Free memory of precalculated rectangles
            this.precalculated_mapping_rectangles = null;

            // Free the mapping memory
            MutexLocks.poppler.lock();
            //Poppler.Page.free_link_mapping(  
            //    this.page_link_mappings
            //);
            MutexLocks.poppler.unlock();
        }
    }
}
