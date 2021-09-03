/**
 * Base action mapping, encapsulating link and annotation mappings.
 *
 * This file is part of pdfpc.
 *
 * Copyright 2012 Robert Schroll
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

namespace pdfpc {
    /**
     * Base action mapping, encapsulating actions that result from links or annotations.
     */
    public abstract class ActionMapping: GLib.Object {
        public enum ActionType {
            LINK,
            MOVIE
        }

        public ActionType type;

        /**
         * The area on the PDF page associated with the action.
         */
        public Poppler.Rectangle area;

        /**
         * The presentation controller, which is probably needed to execute actions.
         */
        protected PresentationController controller;

        /**
         * Constructors of ActionMapping classes shouldn't actually do much.  These
         * objects will generally be made with the new_from_... methods, below.
         * Unlike constructors, these have the option of returning null.  Since I
         * couldn't figure out how to make class objects in Vala, those are object
         * methods, and we need blank objects to call them.  Thus, this blank
         * constructor.
         */
        protected ActionMapping() {
            base();
        }

        /**
         * Instead of in the constructor, most setup is done in the init method.
         */
        public virtual void init(Poppler.Rectangle area,
            PresentationController controller) {
            this.area = area;
            this.controller = controller;
        }

        /**
         * Create and return a new ActionMapping object from the LinkMapping, or
         * return null if this class doesn't handle this type of LinkMapping.  Note
         * that this is an object method, not a static method, which makes it easier
         * to figure out if you're in a subclass.
         */
        public virtual ActionMapping? new_from_link_mapping(Poppler.LinkMapping mapping,
                PresentationController controller) {
            return null;
        }

        /**
         * Create and return a new ActionMapping object from the AnnotMapping, or
         * return null if this class doesn't handle this type of AnnotMapping.
         */
        public virtual ActionMapping? new_from_annot_mapping(Poppler.AnnotMapping mapping,
                PresentationController controller) {
            return null;
        }

        /**
         * Override this method to get notified of the mouse entering the area.
         */
        public virtual void on_mouse_enter(Gtk.Widget widget, Gdk.EventMotion event) {
            return;
        }

        /**
         * Override this method to get notified of the mouse exiting the area.
         */
        public virtual void on_mouse_leave(Gtk.Widget widget, Gdk.EventMotion event) {
            return;
        }

        /**
         * Handle mouse press/release/motion events in the area. Return true to
         * indicate that the event has been handled.
         */
        public virtual bool on_button_press(Gtk.Widget widget, Gdk.EventButton event) {
            return false;
        }
        public virtual bool on_button_release(Gtk.Widget widget, Gdk.EventButton event) {
            return false;
        }
        public virtual bool on_mouse_move(Gtk.Widget widget, Gdk.EventMotion event) {
            return false;
        }

        /**
         * By default, all mappings are active only in the normal mode.
         * Override to change this (probably, there will never be a need).
         */
        public virtual bool is_sensitive() {
            return this.controller.in_normal_mode();
        }

        /**
         * Override this method to get notified of the freeze toggle events.
         */
        public virtual void on_freeze(bool frozen) {
            return;
        }

        /**
         * Called when leaving the page.  Override to clean up after yourself.
         */
        public virtual void deactivate() {
            return;
        }
    }
}
