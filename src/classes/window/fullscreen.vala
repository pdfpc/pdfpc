/**
 * Fullscreen Window
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

namespace org.westhoffswelt.pdfpresenter.Window {
    /**
     * Window extension implementing all the needed functionality, to be
     * displayed fullscreen.
     *
     * Methods to specify the monitor to be displayed on in a multi-head setup
     * are provided as well.
     */
    public class Fullscreen: Gtk.Window {
        /**
         * The geometry data of the screen this window is on
         */
        protected Rectangle screen_geometry;

        /**
         * Timer id which monitors mouse motion to hide the cursor after 5
         * seconds of inactivity
         */
        protected uint hide_cursor_timeout = 0;

        public Fullscreen( int screen_num ) {
            var screen = Screen.get_default();
            screen.get_monitor_geometry( screen_num, out this.screen_geometry );

            // Move to the correct monitor
            // This movement is done here and after mapping, to minimize flickering
            // with window managers, which correctly handle the movement command,
            // before the window is mapped.
            this.move( this.screen_geometry.x, this.screen_geometry.y );
            this.fullscreen();

            // As certain window-managers like Xfwm4 ignore movement request
            // before the window is initially moved and set up we need to
            // listen to this event.
            this.size_allocate.connect( this.on_size_allocate );

            this.add_events(EventMask.POINTER_MOTION_MASK);
            this.motion_notify_event.connect( this.on_mouse_move );

            // Start the 5 seconds timeout after which the mouse curosr is
            // hidden
            this.restart_hide_cursor_timer();
        }

        /**
         * Called if window size is allocated
         *
         * This method is needed, because certain window manager (eg. Xfwm4) ignore
         * movement commands before the window has been displayed for the first
         * time.
         */
        protected void on_size_allocate( Gtk.Widget source, Rectangle r ) {
            if ( this.is_mapped() ) {
                // We are only interested to handle this event AFTER the window has
                // been mapped.

                // Remove the signal handler, as we only want to handle this once
                this.size_allocate.disconnect( this.on_size_allocate );

                // We only need to do all this, if the window is not at the
                // correct position. Otherwise it would only cause flickering
                // without any effect.
                int x,y;
                this.get_position( out x, out y );
                if ( x == this.screen_geometry.x && y == this.screen_geometry.y ) {
                    return;
                }

                // Certain window manager (eg. Xfce4) do not allow window movement
                // while the window is maximized. Therefore it is ensured the
                // window is not in this state.
                this.unfullscreen();
                this.unmaximize();

                // The first movement might not have worked as expected, because of
                // the before mentioned maximized window problem. Therefore it is
                // done again
                this.move( this.screen_geometry.x, this.screen_geometry.y );

                this.fullscreen();
            }
        }

        /**
         * Called every time the mouse cursor is moved
         */
        protected bool on_mouse_move( Gtk.Widget source, EventMotion event ) {
            // Restore the mouse cursor to its default value
            this.window.set_cursor( null );

            this.restart_hide_cursor_timer();
            
            return false;
        }

        /**
         * Restart the 5 seconds timeout before hiding the mouse cursor
         */
        protected void restart_hide_cursor_timer(){
            if ( this.hide_cursor_timeout != 0 ) {
                Source.remove( this.hide_cursor_timeout );
            }

            this.hide_cursor_timeout = Timeout.add_seconds(
                5,
                this.on_hide_cursor_timeout
            );
        }

        /**
         * Timeout method called if the mouse pointer has not been moved for 5
         * seconds
         */
        protected bool on_hide_cursor_timeout() {
            this.hide_cursor_timeout = 0;

            // Window might be null in case it has not been mapped
            if ( this.window != null ) {
                this.window.set_cursor(
                    new Gdk.Cursor( 
                        Gdk.CursorType.BLANK_CURSOR
                    )
                );

                // After the timeout disabled the cursor do not run it again
                return false;
            }
            else {
                // The window was not available. Possibly it was not mapped
                // yet. We simply try it again if the mouse isn't moved for
                // another five seconds.
                return true;
            }
        }
    }
}
