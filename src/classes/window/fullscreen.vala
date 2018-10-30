/**
 * Fullscreen Window
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011, 2012 David Vilar
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2014,2016 Andy Barry
 * Copyright 2015,2017 Andreas Bilke
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
         * Overlay layout. Holds all drawing layers (like the pdf,
         * the pointer mode etc)
         */
        protected Gtk.Overlay overlay_layout;

        /**
         * Drawing area for pointer mode
         */
        public Gtk.DrawingArea pointer_drawing_surface { get; protected set; }

        /**
         * Drawing area for pen mode
         */
        public Gtk.DrawingArea pen_drawing_surface { get; protected set; }

        /**
         * Video area for playback. All videos are added to this surface.
         */
        public View.Video video_surface { get; protected set; }

        /**
         * Stores if the view is frozen
         */
        protected bool frozen = false;

        /**
         * The GDK scale factor. Used for better slide rendering
         */
        protected int gdk_scale = 1;

        /**
         * The screen we want this window to be shown
         */
        protected Gdk.Screen screen_to_use;

        /**
         * The monitor number we want to show the window
         */
        protected int screen_num_to_use;

        public Fullscreen(int screen_num, int width = -1, int height = -1) {
            if (screen_num >= 0) {
                this.screen_num_to_use = screen_num;

                // Start in the given monitor
                this.screen_to_use = Gdk.Screen.get_default();
            } else {
                // Start in the monitor the cursor is in
                var device = Gdk.Display.get_default().get_default_seat().get_pointer();
                int pointerx, pointery;
                device.get_position(out this.screen_to_use, out pointerx, out pointery);

                this.screen_num_to_use = this.screen_to_use.get_monitor_at_point(pointerx, pointery);
            }
            this.screen_to_use.get_monitor_geometry(this.screen_num_to_use, out this.screen_geometry);

            this.gdk_scale = this.screen_to_use.get_monitor_scale_factor(this.screen_num_to_use);
            if (Pdfpc.is_Wayland_backend() && Options.wayland_workaround) {
                // See issue 214. Wayland is doing some double scaling therefore
                // we are lying about the actual screen size
                this.screen_geometry.width /= this.gdk_scale;
                this.screen_geometry.height /= this.gdk_scale;
            }

            this.overlay_layout = new Gtk.Overlay();
            this.overlay_layout.halign = Gtk.Align.CENTER;
            this.overlay_layout.valign = Gtk.Align.CENTER;

            this.pointer_drawing_surface = new Gtk.DrawingArea();
            this.pen_drawing_surface = new Gtk.DrawingArea();
            this.video_surface = new View.Video();

            this.overlay_layout.add_overlay(this.video_surface);
            this.overlay_layout.add_overlay(this.pen_drawing_surface);
            this.overlay_layout.add_overlay(this.pointer_drawing_surface);

            this.video_surface.realize.connect(() => {
                this.set_widget_event_pass_though(this.video_surface, true);
            });
            this.pen_drawing_surface.realize.connect(() => {
                this.set_widget_event_pass_though(this.pen_drawing_surface, true);
            });
            this.pointer_drawing_surface.realize.connect(() => {
                this.set_widget_event_pass_though(this.pointer_drawing_surface, true);
            });

            this.pointer_drawing_surface.halign = Gtk.Align.FILL;
            this.pointer_drawing_surface.valign = Gtk.Align.FILL;

            this.pen_drawing_surface.halign = Gtk.Align.FILL;
            this.pen_drawing_surface.valign = Gtk.Align.FILL;

            this.video_surface.halign = Gtk.Align.FILL;
            this.video_surface.valign = Gtk.Align.FILL;

            // Make the window resizable to allow the window manager
            // to correctly fit it to the screen. (Note: allegedly
            // this presents a problem for some window managers, but
            // setting resizable to false prevents full-screen from
            // working)
            this.resizable = true;

            if (!Options.windowed) {
                // start moving and fullscreening after the window was shown initially
                this.map_event.connect(this.on_mapped);
            } else {
                if (width > 0 && height > 0) {
                        this.screen_geometry.width = width;
                        this.screen_geometry.height = height;
                } else {
                        this.screen_geometry.width /= 2;
                        this.screen_geometry.height /= 2;
                }
                this.resizable = false;
            }

            this.set_size_request(this.screen_geometry.width, this.screen_geometry.height);

            this.add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            this.motion_notify_event.connect(this.on_mouse_move);

            // Start the 5 seconds timeout after which the mouse cursor is
            // hidden
            this.restart_hide_cursor_timer();
        }

        /**
         * Move/fullscreen after the window was shown for the first time.
         * Some WM ignore move requests before the window was shown initially so
         * we wait until the window has been shown.
         */
        protected bool on_mapped(Gdk.EventAny event) {
            if (event.type != Gdk.EventType.MAP) {
                return false;
            }

            // move does not work on wayland sessions correctly, since wayland
            // has no concept of global coordinates. For X11, this does the
            // right thing.  On Wayland, the window is "somewhere", but we do
            // not care, since the next call should fix it.
            this.move(this.screen_geometry.x, this.screen_geometry.y);

            // In wayland sessions we should end up on the correct monitor in
            // fullscreen state. In X11, this API call is not implemented
            // correctly until gtk 3.22. For X11 with gtk < 3.22, this call is
            // just switching to fullscreen on the current screen. Since we
            // moved it to the correct screen anyways, we should be safe here.
            this.fullscreen_on_monitor(this.screen_to_use, this.screen_num_to_use);

            return true;
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

        /**
         * Set the widget passthrough.
         *
         * If set to true, the widget will not receive events and they will be forwarded to the
         * underlying widgets within the Gtk.Overlay
         */
        protected void set_widget_event_pass_though(Gtk.Widget w, bool pass_through) {
            this.overlay_layout.set_overlay_pass_through(w, pass_through);
        }
    }
}

