/**
 * Application wide options
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011, 2012 David Vilar
 * Copyright 2012, 2015 Andreas Bilke
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2014 Andy Barry
 * Copyright 2015 Jeremy Maitin-Shepard
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

namespace pdfpc {
    /**
     * Static property container holding the application wide option
     * information and their default values.
     */
    public class Options: GLib.Object {
        static construct {
            key_bindings = new Gee.ArrayList<BindTuple>();
            mouse_bindings = new Gee.ArrayList<BindTuple>();
        }

        /**
         * Commandline option enabeling the execution of external
         * scripts. Only the scripts explicitly given on the
         * commandline can be executed.
         */
        public static string external_script = "none";
        
        /**
         * Commandline option specifying if the presenter and presentation screen
         * should be switched.
         */
        public static bool display_switch = false;

        /**
         * Commandline option to force using only one screen.
         */
        public static bool single_screen = false;

        /**
         * Type of the windowed mode
         */
        public static string windowed = null;

        /**
         * Commandline option to enable Wayland specific scaling workarounds
         */
        public static bool wayland_workaround = false;

        /**
         * Undocumented on purpose...
         */
        public static bool cache_debug = false;

        /**
         * Periodicity with which the cache cleaner is fired [s]
         */
        public static int cache_clean_period = 60;

        /**
         * Time duration for (pre)rendered pages to be kept in cache [s]
         */
        public static int cache_expiration = 600;

        /**
         * Config option defining maximal render time of slide for its cache
         * to be never evicted [ms]
         */
        public static int cache_max_rtime = 1000;

        /**
         * Config option defining minimal render time of slide to be cached [ms]
         */
        public static int cache_min_rtime = 10;

        /**
         * Config option defining maximal slide size to be stored uncompressed
         * [kB]
         */
        public static int cache_max_usize = 256;

        /**
         * Delay before starting prerendering consecutive slides [s]
         */
        public static int prerender_delay = 4;

        /**
         * Number of slides ahead of the current one to prerender;
         * 0 to disable, negative => prerender all
         */
        public static int prerender_slides = 2;

        /**
         * Config option to enable a workaround for fullscreen window placement
         * (needed for some WM's, e.g., fvwm)
         */
        public static bool move_on_mapped = false;

        /**
         * Config option to disable detection of tablet input type (pen|eraser)
         */
        public static bool disable_input_autodetection = false;

        /**
         * Config option to disable pressure sensitivity of tablet pens/erasers
         */
        public static bool disable_input_pressure = false;

        /**
         * Config option to disable scrolling events on the presenter window.
         */
        public static bool disable_scrolling = false;

        /**
         * Commandline option to disable the auto detection of overlay slides
         */
        public static bool disable_auto_grouping = false;

        /**
         * Commandline option providing the talk duration, which will be used to
         * display a timer
         *
         * Same problem as above with default value
         */
        public static uint duration = uint.MAX;

        /**
         * Commandline option providing the time from which on the timer should
         * change its color.
         */
        public static uint last_minutes = 5;

        /**
         * Commandline option providing the size of the current slide in
         * the presenter window
         */
        public static uint current_size = 60;

        /**
         * Commandline option providing the height of the current slide in
         * the presenter window
         **/
        public static uint current_height = 80;

        /**
         * Commandline option providing the maximum height of the next slide
         * in the presenter window
         **/
        public static uint next_height = 70;

        /**
         * Minimum width for the overview miniatures
         */
        public static int min_overview_width = 150;

        /**
         * Time the talk starts at, to calculate and display a countdown to
         * this time.
         */
        public static string? start_time = null;

        /**
         * Use the current time of the day as a timer
         */
        public static bool use_time_of_day = false;

        /**
         * Use the new coloring mode of the timer according to the actual
         * progress
         */
        public static bool timer_pace_color = true;

        /**
         * Time the talk should end
         */
        public static string? end_time = null;

        /**
         * Add a black slide at the end of the presentation
         */
        public static bool black_on_end = false;

        /**
         * Show the actions supported in the config file(s)
         */
        public static bool list_actions = false;

        /**
         * Show the defined action bindings
         */
        public static bool list_bindings = false;

        /**
         * Show the available monitors(s)
         */
        public static bool list_monitors = false;

        /**
         * Position of notes on slides
         */
        public static string? notes_position = null;

        /**
         * Screen to be used for the presentation (output name)
         */
        public static string? presentation_screen = null;

        /**
         * Screen to be used for the presenter (output name)
         */
        public static string? presenter_screen = null;

        /**
         * Size of the presenter window
         */
        public static string? size = null;

        /**
         * Pointer color
         */
        public static string pointer_color = "red";

        /**
         * Pointer opacity (0 - 100)
         */
        public static int pointer_opacity = 50;

        /**
         * Pointer size
         */
        public static uint pointer_size = 10;

        /**
         * Try to automatically load video srt file
         */
        public static bool auto_srt = false;

        /**
         * Page which should be displayed after startup
         */
        public static int page = 1;

        /**
         * Flag if the version string should be printed on startup
         */
        public static bool version = false;

        /**
         * Location of specific, user-chosen pdfpcrc file
         */
        public static string? pdfpc_location = null;

        /**
         * Test pdfpc without installation
         */
        public static bool no_install = false;

        /**
         * Show the final slide of each overlay in "next slide" view
         * instead of the next slide.
         */
        public static bool final_slide_overlay = false;

        public class BindTuple {
            public string type;
            public uint keyCode;
            public uint modMask;
            public string actionName;

            private string? _actionArg;
            public string? actionArg {
                get {
                    return _actionArg;
                }
            }

            public void setActionArg(string? actionArg) throws ConfigFileError {
                if (this.actionName != "setPenColor" &&
                    this.actionName != "switchMode") {
                    throw new ConfigFileError.INVALID_BIND("Only 'setPenColor' accepts an action argument");
                }

                this._actionArg = actionArg;
            }
        }

        /**
         * Global storage for key un/bindings from the config file.
         * Used to post pone binding execution in presentation controller
         */
        public static Gee.List<BindTuple> key_bindings;

        /**
         * Global storage for mouse un/bindings from the config file.
         * Used to post pone binding execution in presentation controller
         */
        public static Gee.List<BindTuple> mouse_bindings;

        /**
         * Defines direction/orientation of the toolbox
         */
        public enum ToolboxDirection {
            LtoR,
            RtoL,
            TtoB,
            BtoT;

            public static ToolboxDirection parse(string? dir) {
                if (dir == null) {
                    return LtoR;
                }

                switch (dir.down()) {
                    case "ltor":
                        return LtoR;
                    case "rtol":
                        return RtoL;
                    case "ttob":
                        return TtoB;
                    case "btot":
                        return BtoT;
                    default:
                        return LtoR;
                }
            }
        }

        /**
         * Direction of the toolbox
         */
        public static ToolboxDirection toolbox_direction =
            ToolboxDirection.LtoR;

        /**
         * State of the toolbox
         */
        public static bool toolbox_shown = false;
        public static bool toolbox_minimized = false;
    }
}
