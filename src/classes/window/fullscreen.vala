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
 * the Free Software Foundation; either version 3 of the License, or
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
     * Window extension implementing the needed functionality to be
     * displayed/toggled fullscreen, including multi-head configurations.
     */
    public class Fullscreen : Gtk.Window {
        /**
         * The geometry of this window
         */
        public int window_w { get; protected set; }
        public int window_h { get; protected set; }

        /**
         * Currently selected windowed (!=fullscreen) mode
         */
        protected bool windowed;

        /**
         * The GDK scale factor. Used for better slide rendering
         */
        public int gdk_scale {
            get; protected set;
        }

        /**
         * The screen we want this window to be shown
         */
        protected Gdk.Screen screen_to_use;

        /**
         * The monitor number we want to show the window
         */
        protected int monitor_num_to_use;
        /**
         * ... and the actual monitor object
         */
        public Gdk.Monitor monitor {
            get; protected set;
        }

        protected virtual void resize_gui() {}

        public Fullscreen(int monitor_num, bool windowed,
            int width = -1, int height = -1) {
            this.windowed = windowed;

            var display = Gdk.Display.get_default();
            if (monitor_num >= 0) {
                // Start in the given monitor
                this.monitor = display.get_monitor(monitor_num);
                this.monitor_num_to_use = monitor_num;

                this.screen_to_use = display.get_default_screen();
            } else {
                // Start in the monitor the cursor is in
                var device = display.get_default_seat().get_pointer();
                int pointerx, pointery;
                device.get_position(out this.screen_to_use,
                    out pointerx, out pointery);

                this.monitor = display.get_monitor_at_point(pointerx, pointery);
                // Shouldn't be used, just a safety precaution
                this.monitor_num_to_use = 0;
            }

            this.gdk_scale = this.monitor.get_scale_factor();

            // By default, we go fullscreen
            var monitor_geometry = this.monitor.get_geometry();
            this.window_w = monitor_geometry.width;
            this.window_h = monitor_geometry.height;
            if (Pdfpc.is_Wayland_backend() && Options.wayland_workaround) {
                // See issue 214. Wayland is doing some double scaling therefore
                // we are lying about the actual screen size
                this.window_w /= this.gdk_scale;
                this.window_h /= this.gdk_scale;
            }

            if (!this.windowed) {
                if (Options.move_on_mapped) {
                    // Some WM's ignore move requests made prior to
                    // mapping the window
                    this.map_event.connect(() => {
                            this.do_fullscreen();
                            return true;
                        });
                } else {
                    this.do_fullscreen();
                }
            } else {
                if (width > 0 && height > 0) {
                    this.window_w = width;
                    this.window_h = height;
                } else {
                    this.window_w /= 2;
                    this.window_h /= 2;
                }

                if (Options.move_on_mapped) {
                    // Some WM's ignore move requests made prior to
                    // mapping the window
                    this.map_event.connect(() => {
                            this.move(monitor_geometry.x, monitor_geometry.y);
                            return true;
                        });
                } else {
                    this.move(monitor_geometry.x, monitor_geometry.y);
                }
            }

            this.set_default_size(this.window_w, this.window_h);

            // Watch for changes of the window geometry or monitor switched;
            // keep the local copies updated
            this.configure_event.connect((ev) => {
                    if (this.windowed) {
                        var new_monitor =
                            display.get_monitor_at_window(ev.window);

                        if (new_monitor != this.monitor) {
                            this.monitor = new_monitor;

                            int n_monitors = display.get_n_monitors();
                            for (int i = 0; i < n_monitors; i++) {
                                if (display.get_monitor(i) == new_monitor) {
                                    this.monitor_num_to_use = i;
                                }
                            }
                        }
                    }

                    if (ev.width != this.window_w ||
                        ev.height != this.window_h) {
                        this.window_w = ev.width;
                        this.window_h = ev.height;

                        // Resize any GUI elements if needed
                        this.resize_gui();
                    }
                    return false;
                });
        }

        protected void do_fullscreen() {
            // This should not happen, just in case...
            if (this.monitor == null) {
                return;
            }
            // Wayland has no concept of global coordinates, so move() does not
            // work there. The window is "somewhere", but we do not care,
            // since the next call should fix it. For X11 and KWin/Plasma this
            // does the right thing.
            Gdk.Rectangle monitor_geometry = this.monitor.get_geometry();
            this.move(monitor_geometry.x, monitor_geometry.y);

            // Specially for Wayland; just fullscreen() would do otherwise...
            this.fullscreen_on_monitor(this.screen_to_use,
                this.monitor_num_to_use);
        }

        public void toggle_windowed() {
            this.windowed = !this.windowed;
            if (!this.windowed) {
                var window = this.get_window();
                if (window != null) {
                    this.do_fullscreen();
                }
            } else {
                this.unfullscreen();
            }
        }

        public void connect_monitor(Gdk.Monitor? monitor) {
            // This will likely become beefier in the future
            this.monitor = monitor;
        }

        public bool is_monitor_connected() {
            return this.monitor != null ? true:false;
        }
    }
}
