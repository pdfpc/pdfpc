/**
 * Default slide view
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
using Cairo;
using Gdk;

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Basic view class which is usable with any renderer.
     */
    public class View.Default: View.Base,
        View.Prerendering, View.Behaviour.Decoratable {
        
        /**
         * The currently displayed slide
         */
        protected int current_slide_number;

        /**
         * The current slide in "user indexes"
         */
        protected int current_user_slide_number;

        /**
         * The pixmap containing the currently shown slide
         */
        protected Gdk.Pixmap current_slide;

        /**
         * A flag signaling if we allow for a black slide at the end. Tis is
         * useful for the next view and (for some presenters) also for the main
         * view.
         */
        protected bool black_on_end;

        /**
         * The number of slides in the presentation
         */
        protected int n_slides;

        /**
         * The biggest slide number that we allow (dependent on black_on_end)
         */
        protected int slide_limit;

        /**
         * This is a virtual mapping of "real pages" to "user-view pages". The
         * indexes in the vector are the user-view slide, the contents are the
         * real slide numbers.
         */
        protected int[] user_view_indexes;

        /**
         * List to store all associated behaviours
         */
        protected GLib.List<View.Behaviour.Base> behaviours = new GLib.List<View.Behaviour.Base>();

        /**
         * Base constructor taking the renderer to use as an argument
         */
        public Default( Renderer.Base renderer, bool allow_black_on_end ) {
           base( renderer );

           // As we are using our own kind of double buffer and blit in a one
           // time action, we do not need gtk to double buffer as well.
           this.set_double_buffered( false );

           this.current_slide_number = 0;
           this.current_user_slide_number = 0;
        
           this.n_slides = (int)renderer.get_metadata().get_slide_count();
           stdout.printf("n_slides = %d\n", this.n_slides);
           this.black_on_end = allow_black_on_end;
           if (this.black_on_end)
               this.slide_limit = this.n_slides + 1;
           else
               this.slide_limit = this.n_slides;

           // Read which slides we have to skip
           try {
                string raw_data;
                FileUtils.get_contents("skip", out raw_data);
                string[] lines = raw_data.split("\n"); // Note, there is a "ficticious" line at the end
                int s = 0; // Counter over real slides
                int us = 0; // Counter over user slides
                user_view_indexes.resize(this.n_slides - lines.length + 1);
                for ( int l=0; l < lines.length-1; ++l ) {
                    int current_skip = int.parse( lines[l] ) - 1;
                    while ( s < current_skip ) {
                        user_view_indexes[us++] = s;
                        ++s;
                    }
                    ++s;
                }
                // Now we have to reach the end
                while ( s < this.n_slides ) {
                    user_view_indexes[us++] = s;
                    ++s;
                }
           } catch (GLib.FileError e) {
                stderr.printf("Could not read skip information\n");
           }
           stdout.printf("user_view_indexes = [");
           for ( int s=0; s < user_view_indexes.length; ++s)
                stdout.printf("%d ", user_view_indexes[s]);
           stdout.printf("]\n");

           // Render the initial page on first realization.
           this.add_events( Gdk.EventMask.STRUCTURE_MASK );
           this.realize.connect( () => {
                try {
                    this.display( this.current_slide_number );
                }
                catch( Renderer.RenderError e ) {
                    // There should always be a page 0 but you never know.
                    error( "Could not render initial page %d: %s", this.current_slide_number, e.message );
                }

                // Start the prerender cycle if the renderer supports caching
                // and the used cache engine allows prerendering.
                // Executing the cycle here to ensure it is executed within the
                // Gtk event loop. If it is not proper Gdk thread handling is
                // impossible.
                var caching_renderer = this.renderer as Renderer.Caching;
                if ( caching_renderer != null
                  && caching_renderer.get_cache() != null 
                  && caching_renderer.get_cache().allows_prerendering()) {
                    this.register_prerendering();
                }
           });
        }

        /**
         * Start a thread to prerender all slides this view might display at
         * some time.
         *
         * This method may only be called from within the Gtk event loop, as
         * thread handling is borked otherwise.
         */
        protected void register_prerendering() {
            // The pointer is needed to keep track of the slide progress inside
            // the prerender function
            int* i = null;
            // The page_count will be transfered into the lamda function as
            // well.
            var page_count = this.get_renderer().get_metadata().get_slide_count();
                
            this.prerendering_started();

            Idle.add(() => {
                if( i == null ) {
                    i = malloc( sizeof( int ) );
                    *i = 0;
                }

                // We do not care about the result, as the
                // rendering function stores the rendered
                // pixmap in the cache if it is enabled. This
                // is exactly what we want.
                try {
                    this.get_renderer().render_to_pixmap( *i );
                }
                catch( Renderer.RenderError e ) {
                    error( "Could not render page '%i' while pre-rendering: %s", *i, e.message );
                }
                
                // Inform possible observers about the cached slide
                this.slide_prerendered();
                
                // Increment one slide for each call and stop the loop if we
                // have reached the last slide
                *i = *i + 1;
                if ( *i >= page_count ) {
                    this.prerendering_completed();
                    free( i );
                    return false;
                }
                else {
                    return true;
                }
            });
        }

        /**
         * Associate a new Behaviour with this View
         *
         * The implementation supports an arbitrary amount of different
         * behaviours.
         */
        public void associate_behaviour( Behaviour.Base behaviour ) {
            this.behaviours.append( behaviour );
            try {
                behaviour.associate( this );
            }
            catch( Behaviour.AssociationError e ) {
                error( "Behaviour association failure: %s", e.message );
            }
        }
        
        /**
         * Goto the next slide
         *
         * If the end of slides is reached this method does nothing.
         */
        public override void next() {
            if ( this.slide_limit <= this.current_slide_number + 1 ) {
                // The last slide has been reached, do nothing.
                return;
            }
            
            try {
                this.display( this.current_slide_number + 1 );
                // Update the user slide_number
                if (this.current_slide_number == this.user_view_indexes[this.current_user_slide_number+1]) {
                    // Note: current_slide_number has been updated in display()
                    ++this.current_user_slide_number;
                }
                    
            }
            catch( Renderer.RenderError e ) {
                // Should actually never happen, but one never knows
                error( "Could not display next slide: %s", e.message );
            }
        }

        /**
         * Goto forward n slides
         *
         * If the end of slides is reached this method does nothing.
         */
        public override void jumpN( int n ) {
            try {
                if ( this.current_slide_number + n >= this.slide_limit ) {
                    // Jump to the last slide
                    this.display((int) this.slide_limit - 1) ;
                } else {
                    this.display( this.current_slide_number + n );
                }
            }
            catch( Renderer.RenderError e ) {
                // Should actually never happen, but one never knows
                error( "Could not display next slide: %s", e.message );
            }
        }

        /**
         * Goto the previous slide
         *
         * If the beginning of slides is reached this method does nothing.
         */
        public override void previous() {
            if ( this.current_slide_number - 1 < 0 ) {
                // The first slide has been reached, do nothing.
                return;
            }
            
            try {
                if (this.current_user_slide_number > 0)
                    --this.current_user_slide_number;
                this.display( this.user_view_indexes[this.current_user_slide_number] );
            }
            catch( Renderer.RenderError e ) {
                // Should actually never happen, but one never knows
                error( "Could not display previous slide: %s", e.message );
            }
        }

        /**
         * Go back n slides
         *
         * If the beginning of slides is reached this method does nothing.
         */
        public override void backN( int n ) {
            try {
                if ( this.current_slide_number - n < 0 ) {
                    this.display( 0 );
                } else {
                    this.display( this.current_slide_number - n );
                }
            }
            catch( Renderer.RenderError e ) {
                // Should actually never happen, but one never knows
                error( "Could not display previous slide: %s", e.message );
            }
        }

        /**
         * Goto a specific slide number
         *
         * If the slide number does not exist a
         * RenderError.SLIDE_DOES_NOT_EXIST is thrown
         */
        public override void display( int slide_number, bool force_redraw=false )
            throws Renderer.RenderError {
            // If the slide is out of bounds render the outer most slide on
            // each side of the document.
            if ( slide_number < 0 ) {
                slide_number = 0;
            }
            if ( slide_number >= this.slide_limit ) {
                slide_number = this.slide_limit - 1;
            }

            if ( !force_redraw && slide_number == this.current_slide_number && this.current_slide != null ) {
                // The slide does not need to be changed, as the correct one is
                // already shown.
                return;
            }

            // Notify all listeners
            this.leaving_slide( this.current_slide_number, slide_number );

            // Render the requested slide
            // An exception is thrown here, if the slide can not be rendered.
            if (slide_number < this.n_slides)
                this.current_slide = this.renderer.render_to_pixmap( slide_number );
            else
                this.current_slide = this.renderer.fade_to_black();
            this.current_slide_number = slide_number;

            // Have Gtk update the widget
            this.queue_draw_area( 0, 0, this.renderer.get_width(), this.renderer.get_height() );

            this.entering_slide( this.current_slide_number );
        }

        /**
         * Fill everything with black
         */
        public override void fade_to_black() {
            this.current_slide = this.renderer.fade_to_black();
            this.queue_draw_area( 0, 0, this.renderer.get_width(), this.renderer.get_height() );
        }

        /**
         * Redraw the current slide. Useful for example when exiting from fade_to_black
         */
        public override void redraw() throws Renderer.RenderError {
            this.display(this.current_slide_number, true);
        }

        /**
         * Return the currently shown slide number
         */
        public override int get_current_slide_number() {
            return this.current_slide_number;
        }

        /**
         * This method is called by Gdk every time the widget needs to be redrawn.
         *
         * The implementation does a simple blit from the internal pixmap to
         * the window surface.
         */
        public override bool expose_event ( Gdk.EventExpose event ) {
            Context cr = Gdk.cairo_create( this.window );
            Gdk.cairo_set_source_pixmap(
                cr,
                this.current_slide,
                event.area.x,
                event.area.y
            );
            cr.rectangle(
                event.area.x,
                event.area.y,
                event.area.width,
                event.area.height
            );
            cr.fill();

            // We are the only ones drawing on this context skip everything
            // else.
            return true;
        }
    }
}
