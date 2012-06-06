/**
 * Controllable interface
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

namespace pdfpc {
    /**
     * Every window or object which wants to be controlled by the
     * PresentationController needs to implement this interface.
     */
    public interface Controllable: GLib.Object {
        /**
         * Set the presentation controller which needs to be informed of key
         * presses and such.
         */
        //public abstract void set_controller( PresentationController controller ) ;

        /**
         * Return the registered PresentationController
         */
        public abstract PresentationController? get_controller();

        /**
         * Update the display
         */
        public abstract void update();

        /**
         * Edit note for current slide
         */
        public abstract void edit_note();

        /**
         * Ask for the page to jump to
         */
        public abstract void ask_goto_page();

        /**
         * Show an overview of all slides
         */
        public abstract void show_overview();

        /**
         * Hide the overview
         */
        public abstract void hide_overview();
        
        /**
         * Return the view on which links and annotations should be handled.
         */
        public abstract View.Pdf? get_main_view();
    }
}
