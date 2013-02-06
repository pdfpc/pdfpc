/**
 * Presentation window
 *
 * This file is part of pdfpc.
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

using Gtk;
using Gdk;

using pdfpc;

namespace pdfpc.Window {
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
         * View containing the slide to show
         */
        protected View.Base view;

        /**
         * Base constructor instantiating a new presentation window
         */
        public Presentation( Metadata.Pdf metadata, int screen_num, PresentationController presentation_controller ) {
            base( screen_num );
            this.role = "presentation";

            this.destroy.connect( (source) => {
                presentation_controller.quit();
            } );

            this.presentation_controller = presentation_controller;

            Color black;
            Color.parse( "black", out black );
            this.modify_bg( StateType.NORMAL, black );

            var fixedLayout = new Fixed();
            fixedLayout.set_size_request(this.screen_geometry.width, this.screen_geometry.height);
            this.add( fixedLayout );
            
            Rectangle scale_rect;
            
            this.view = View.Pdf.from_metadata( 
                metadata,
                this.screen_geometry.width, 
                this.screen_geometry.height,
                Metadata.Area.CONTENT,
                Options.black_on_end,
                true,
                this.presentation_controller,
                out scale_rect
            );

            if ( !Options.disable_caching ) {
                ((Renderer.Caching)this.view.get_renderer()).set_cache( 
                    Renderer.Cache.OptionFactory.create( 
                        metadata
                    )
                );
            }

            // Center the scaled pdf on the monitor
            // In most cases it will however fill the full screen
            fixedLayout.put(
                this.view,
                scale_rect.x,
                scale_rect.y
            );

            this.add_events(EventMask.KEY_PRESS_MASK);
            this.add_events(EventMask.BUTTON_PRESS_MASK);
            this.add_events(EventMask.SCROLL_MASK);

            this.key_press_event.connect( this.on_key_pressed );
            this.button_press_event.connect( this.on_button_press );
            this.scroll_event.connect( this.on_scroll );

            this.presentation_controller.register_controllable( this );
        }

        /**
         * Handle keypress vents on the window and, if neccessary send them to the
         * presentation controller
         */
        protected bool on_key_pressed( EventKey key ) {
            if ( this.presentation_controller != null ) {
                this.presentation_controller.key_press( key );
            }
            return false;
        }

        /**
         * Handle mouse button events on the window and, if neccessary send
         * them to the presentation controller
         */
        protected bool on_button_press( EventButton button ) {
            if ( this.presentation_controller != null ) {
                this.presentation_controller.button_press( button );
            }
            return false;
        }

        /**
         * Handle mouse scrolling events on the window and, if neccessary send
         * them to the presentation controller
         */
        protected bool on_scroll( Gtk.Widget source, EventScroll scroll ) {
            if ( this.presentation_controller != null ) {
                this.presentation_controller.scroll( scroll );
            }
            return false;
        }

        /**
         * Set the presentation controller which is notified of keypresses and
         * other observed events
         */
        public void set_controller( PresentationController controller ) {
            this.presentation_controller = controller;
        }

        /**
         * Return the PresentationController
         */
        public PresentationController? get_controller() {
            return this.presentation_controller;
        }

        /**
         * Update the display
         */
        public void update() {
            if (this.presentation_controller.is_faded_to_black()) {
                this.view.fade_to_black();
                return;
            }
            if (this.presentation_controller.is_frozen())
                return;
            try {
                this.view.display(this.presentation_controller.get_current_slide_number(), true);
            }
            catch( Renderer.RenderError e ) {
                GLib.error( "The pdf page %d could not be rendered: %s", this.presentation_controller.get_current_slide_number(), e.message );
            }
        }
            
        /**
         * Edit note for current slide. We don't do anything.
         */
        public void edit_note() {
        }

        /**
         * Ask for the page to jump to. We don't do anything
         */
        public void ask_goto_page() {
        }

        /**
         * Show an overview. We don't do anything (yet?)
         */
        public void show_overview() {
        }

        /**
         * Hide the overview. We don't do anything
         */
        public void hide_overview() {
        }

        /**
         * Set the cache observer for the Views on this window
         *
         * This method takes care of registering all Prerendering Views used by
         * this window correctly with the CacheStatus object to provide acurate
         * cache status measurements.
         */
        public void set_cache_observer( CacheStatus observer ) {
            var prerendering_view = this.view as View.Prerendering;
            if( prerendering_view != null ) {
                observer.monitor_view( prerendering_view );
            }
        }

        /**
         * The only view is the main view.
         */
        public View.Pdf? get_main_view() {
            return this.view as View.Pdf;
        }
    }
}
