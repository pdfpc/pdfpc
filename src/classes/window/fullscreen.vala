/**
 * Fullscreen Window
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011, 2012 David Vilar
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2014,2016 Andy Barry
 * Copyright 2015 Andreas Bilke
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

namespace pdfpc.Window {
    /**
     * Window extension implementing all the needed functionality, to be
     * displayed fullscreen.
     *
     * Methods to specify the monitor to be displayed on in a multi-head setup
     * are provided as well.
     */
    public class Fullscreen : Gtk.Window {
        /**
         * The geometry data of the screen this window is on
         */
        protected Gdk.Rectangle screen_geometry;

        /**
         * Timer id which monitors mouse motion to hide the cursor after 5
         * seconds of inactivity
         */
        protected uint hide_cursor_timeout = 0;

        /**
         * Stores if the view is faded to black
         */
        protected bool faded_to_black = false;

        /**
         * Stores if the view is frozen
         */
        protected bool frozen = false;

        public Fullscreen(int screen_num, int width = -1, int height = -1) {
            Gdk.Screen screen;

            if (screen_num >= 0) {
                // Start in the given monitor
                screen = Gdk.Screen.get_default();
                screen.get_monitor_geometry(screen_num, out this.screen_geometry);
            } else {
                // Start in the monitor the cursor is in
                var display = Gdk.Display.get_default().get_device_manager().get_client_pointer();
                int pointerx, pointery;
                display.get_position(out screen, out pointerx, out pointery);
                int current_screen = screen.get_monitor_at_point(pointerx, pointery);
                screen.get_monitor_geometry(current_screen, out this.screen_geometry);
            }

            // We always render ouput to fit to an exact size.
            // This also forces some tiling window managers like i3 to
            // put the windows on the right screens.
            this.resizable = false;

            if (!Options.windowed) {
                // Move to the correct monitor
                // This movement is done here and after mapping, to minimize flickering
                // with window managers, which correctly handle the movement command,
                // before the window is mapped.
                this.move(this.screen_geometry.x, this.screen_geometry.y);

                // As certain window-managers like Xfwm4 ignore movement request
                // before the window is initially moved and set up we need to
                // listen to this event.
                this.size_allocate.connect(this.on_size_allocate);
                this.configure_event.connect(this.on_configure);
            }
            else {
                if (width > 0 && height > 0) {
                        this.screen_geometry.width = width;
                        this.screen_geometry.height = height;
                } else {
                        this.screen_geometry.width /= 2;
                        this.screen_geometry.height /= 2;
                }
            }

            this.add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            this.motion_notify_event.connect(this.on_mouse_move);

            // Start the 5 seconds timeout after which the mouse curosr is
            // hidden
            this.restart_hide_cursor_timer();
        }

        // We got to fullscreen once we have moved
        protected bool on_configure(Gdk.EventConfigure e) {
            this.fullscreen();
            this.configure_event.disconnect(this.on_configure);
            return false;
        }

        /**
         * Called if window size is allocated
         *
         * This method is needed, because certain window manager (eg. Xfwm4) ignore
         * movement commands before the window has been displayed for the first
         * time.
         */
        protected void on_size_allocate(Gtk.Allocation allocation) {
            if (this.get_mapped()) {
                // We are only interested to handle this event AFTER the window has
                // been mapped.

                // Remove the signal handler, as we only want to handle this once
                this.size_allocate.disconnect(this.on_size_allocate);

                // We only need to do all this, if the window is not at the
                // correct position. Otherwise it would only cause flickering
                // without any effect.
                int x, y;
                this.get_position(out x, out y);
                if (x == this.screen_geometry.x && y == this.screen_geometry.y) {
                    return;
                }

                // The first movement might not have worked as expected, because of
                // the before mentioned maximized window problem. Therefore it is
                // done again
                this.move(this.screen_geometry.x, this.screen_geometry.y);

                this.fullscreen();

                // Check to see if that move was successful
                this.get_position(out x, out y);
                if (x == this.screen_geometry.x && y == this.screen_geometry.y) {
                    return;
                }

                // That move failed.  Now unfullscreen in case the window
                // is too large for the other screen, preventing a
                // successful move to that screen and try again.
                this.unfullscreen();
                this.move(this.screen_geometry.x, this.screen_geometry.y);
                this.fullscreen();
            }
        }

        /**
         * Called every time the mouse cursor is moved
         */
        public bool on_mouse_move(Gtk.Widget source, Gdk.EventMotion event) {
            // Restore the mouse cursor to its default value
            this.get_window().set_cursor(null);

            this.restart_hide_cursor_timer();

            return false;
        }

        /**
         * Restart the 5 seconds timeout before hiding the mouse cursor
         */
        protected void restart_hide_cursor_timer(){
            if (this.hide_cursor_timeout != 0) {
                Source.remove(this.hide_cursor_timeout);
            }

            this.hide_cursor_timeout = Timeout.add_seconds(5, this.on_hide_cursor_timeout);
        }

        /**
         * Timeout method called if the mouse pointer has not been moved for 5
         * seconds
         */
        protected bool on_hide_cursor_timeout() {
            this.hide_cursor_timeout = 0;

            // Window might be null in case it has not been mapped
            if (this.get_window() != null) {
                var cursor = new Gdk.Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.BLANK_CURSOR);
                this.get_window().set_cursor(cursor);

                // After the timeout disabled the cursor do not run it again
                return false;
            } else {
                // The window was not available. Possibly it was not mapped
                // yet. We simply try it again if the mouse isn't moved for
                // another five seconds.
                return true;
            }
        }
    }
}

