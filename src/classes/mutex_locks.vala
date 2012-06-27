/**
 * Application wide mutex locks
 *
 * This file is part of pdfpc.
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

namespace pdfpc {
    /**
     * Static property container holding all mutex locks, which are needed
     * throughout the application.
     */
    public class MutexLocks: Object {
       /**
        * Lock which needs to be used every time poppler is used.
        *
        * Unfortunately the poppler library is not threadsafe.
        */
       public static Mutex poppler;

        /**
         * Initialize all used mutex objects for the first time
         */
       public static void init() {
           MutexLocks.poppler = new Mutex();
       }
    }
}
