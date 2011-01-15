/**
 * Controllable interface
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
     * Every window or object which wants to be controlled by the
     * PresentationController needs to implement this interface.
     */
    public interface Controllable: GLib.Object {
        /**
         * Set the presentation controller which needs to be informed of key
         * presses and such.
         */
        public abstract void set_controller( PresentationController controller ) ;

        /**
         * Return the registered PresentationController
         */
        public abstract PresentationController? get_controller();

        /**
         * Change the presentation slide to the next page if applicable
         */
        public abstract void next_page();

        /**
         * Change the presentation slide to the previous page if applicable.
         */
        public abstract void previous_page();

        /**
         * Reset the presentation to it's initial state
         */
        public abstract void reset();

        /**
         * Display a certain page
         */
        public abstract void goto_page( int page_number );
    }
}
