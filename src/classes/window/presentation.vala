/**
 * Presentation window
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
         * View containing the slide to show
         */
        protected View.Base view;

        /**
         * Base constructor instantiating a new presentation window
         */
        public Presentation( string pdf_filename, int screen_num, PresentationController presentation_controller ) {
            base( screen_num );

            this.destroy.connect( (source) => {
                Gtk.main_quit();
            } );

            this.presentation_controller = presentation_controller;
            this.presentation_controller.register_controllable( this );

            Color black;
            Color.parse( "black", out black );
            this.modify_bg( StateType.NORMAL, black );

            var fixedLayout = new Fixed();
            this.add( fixedLayout );
            
            Rectangle scale_rect;
            
            this.view = View.Pdf.from_pdf_file( 
                pdf_filename,
                this.screen_geometry.width, 
                this.screen_geometry.height,
                Options.black_on_end,
                this.presentation_controller,
                out scale_rect
            );

            if ( !Options.disable_caching ) {
                ((Renderer.Caching)this.view.get_renderer()).set_cache( 
                    Renderer.Cache.OptionFactory.create( 
                        this.view.get_renderer().get_metadata()
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

            this.key_press_event.connect( this.on_key_pressed );
            this.button_press_event.connect( this.on_button_press );

            this.update();
            this.reset();
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
            try {
                this.view.display(this.presentation_controller.get_current_slide_number());
            }
            catch( Renderer.RenderError e ) {
                GLib.error( "The pdf page %d could not be rendered: %s", this.presentation_controller.get_current_slide_number(), e.message );
            }
            this.faded_to_black = false;
        }
            
        /**
         * Reset to the initial presentation state
         */
        public void reset() {
        }

        public void fade_to_black() {
            if (this.faded_to_black) {
                try {
                    this.view.redraw();
                }
                catch ( Renderer.RenderError e ) {
                    GLib.error( "Could not redraw slide: %s", e.message);
                }
            } else {
                this.view.fade_to_black();
            }
            this.faded_to_black = !this.faded_to_black;
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
    }
}
