/**
 * Default slide view
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

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Basic view class which is usable with any renderer.
     */
    public class View.Default: View.Base {
        
        /**
         * The currently displayed slide
         */
        protected int current_slide_number;

        /**
         * The pixmap containing the currently shown slide
         */
        protected Gdk.Pixmap current_slide;

        /**
         * Base constructor taking the renderer to use as an argument
         */
        public Default( Renderer.Base renderer ) {
           base( renderer );

           // As we are using our own kind of double buffer and blit in a one
           // time action, we do not need gtk to double buffer as well.
           this.set_double_buffered( false );

           this.current_slide_number = 0;

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
           });
        }
        
        /**
         * Goto the next slide
         *
         * If the end of slides is reached this method does nothing.
         */
        public override void next() {
            if ( this.renderer.get_metadata().get_slide_count() <= this.current_slide_number + 1 ) {
                // The last slide has been reached, do nothing.
                return;
            }
            
            try {
                this.display( this.current_slide_number + 1 );
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
                this.display( this.current_slide_number - 1 );
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
        public override void display( int slide_number )
            throws Renderer.RenderError {
            if ( slide_number == this.current_slide_number && this.current_slide != null ) {
                // The slide does not need to be changed, as the correct one is
                // already shown.
                return;
            }

            // Notify all listeners
            this.leaving_slide( this.current_slide_number, slide_number );

            // Render the requested slide
            // An exception is thrown here, if the slide can not be rendered.
            this.current_slide = this.renderer.render_to_pixmap( slide_number );
            this.current_slide_number = slide_number;

            // Have Gtk update the widget
            this.queue_draw_area( 0, 0, this.renderer.get_width(), this.renderer.get_height() );

            this.entering_slide( this.current_slide_number );
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
            var gc = new Gdk.GC( this.window );
            this.window.draw_drawable( 
                gc,
                this.current_slide,
                event.area.x,
                event.area.y,
                event.area.x,
                event.area.y,
                event.area.width,
                event.area.height
            );

            // We are the only ones drawing on this context skip everything
            // else.
            return true;
        }
    }
}
