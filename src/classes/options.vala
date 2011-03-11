/**
 * Application wide options
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

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Static property container holding the application wide option
     * information and their default values.
     */
    public class Options: GLib.Object {
        /**
         * Commandline option specifying if the presenter and presentation screen
         * should be switched.
         */
        public static bool display_switch = false;
        
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
         * Commandline option providing the talk duration, which will be used to
         * display a timer
         */
        public static uint duration = 45;

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
         * Time the talk starts at, to calculate and display a countdown to
         * this time.
         */
        public static string? start_time = null;
    }
}
