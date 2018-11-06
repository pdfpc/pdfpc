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
         * Commandline option specifying if the presenter and presentation screen
         * should be switched.
         */
        public static bool display_switch = false;

        /**
         * Commandline option to force using only one screen.
         */
        public static bool single_screen = false;

        /**
         * Commandline option to run in windowed mode
         */
        public static bool windowed = false;

        /**
         * Commandline option to enable Wayland specific scaling workarounds
         */
        public static bool wayland_workaround = false;

        /**
         * Commandline option which allows the complete disabling of slide caching
         */
        public static bool disable_caching = false;

        /**
         * Commandline option to disable the compression of cached slides. This
         * trades speed for memory. A lot of memory ;) It's about factor 30
         * bigger for normal presentations.
         */
        public static bool disable_cache_compression = false;

        /**
         * Config option to disable detection of tablet input type (pen|eraser)
         */
        public static bool disable_input_autodetection = false;

        /**
         * Config option to disable scrolling events on the presenter window.
         */
        public static bool disable_scrolling = false;

        /**
         * Commandline option to persist the PNG cache to disk.
         */
        public static bool persist_cache = false;

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
         * Position of notes on slides
         */
        public static string? notes_position = null;

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
