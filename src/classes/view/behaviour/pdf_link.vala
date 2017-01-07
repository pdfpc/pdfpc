/**
 * Signal Provider for all pdf link related events
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012, 2015 Robert Schroll
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

namespace pdfpc.View.Behaviour {
    /**
     * Access provider to all signals related to PDF links.
     */
    public class PdfLink: Base {
        /**
         * The Poppler.LinkMapping which is currently beneath the mouse cursor or null
         * if there is none.
         */
        protected ActionMapping active_mapping = null;

        /**
         * Poppler.LinkMappings of the current page
         */
        protected unowned Gee.List<ActionMapping>? page_link_mappings = null;

        /**
         * Precalculated Gdk.Rectangles for every link mapping
         */
        protected Gdk.Rectangle[] precalculated_mapping_rectangles = null;

        public override void associate(View.Pdf target) throws AssociationError {
            this.enforce_exclusive_association(target);
            this.attach(target);
        }

        /**
         * Attach a View.Pdf to this signal provider
         */
        public void attach(View.Pdf view) {
            this.target = view;

            view.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            view.add_events(Gdk.EventMask.BUTTON_RELEASE_MASK);
            view.add_events(Gdk.EventMask.POINTER_MOTION_MASK);

            view.button_press_event.connect(this.on_button_press);
            view.motion_notify_event.connect(this.on_mouse_move);
            view.entering_slide.connect(this.on_entering_slide);
            view.leaving_slide.connect(this.on_leaving_slide);
        }

        /**
         * Return the Poppler.LinkMapping associated with link for the given
         * coordinates.
         *
         * If there is no link for the given coordinates null is returned
         * instead.
         */
        protected ActionMapping? get_link_mapping_by_coordinates(double x, double y) {
            // Try to find a matching link mapping on the page.
            for(var i = 0; i < this.precalculated_mapping_rectangles.length; ++i) {
                Gdk.Rectangle r = this.precalculated_mapping_rectangles[i];
                // A simple bounding box check tells us if the given point lies
                // within the link area.
                if (   ( x >= r.x )
                    && ( x <= r.x + r.width )
                    && ( y >= r.y )
                    && ( y <= r.y + r.height )) {
                    return this.page_link_mappings.get(i);
                }
            }
            return null;
        }

        /**
         * Called whenever a mouse button is pressed inside the View.Pdf
         *
         * Maybe a link has been clicked. Therefore we need to handle this.
         */
        protected bool on_button_press(Gtk.Widget source, Gdk.EventButton e) {
            // In case the coords belong to a link we will get its action. If
            // they are pointing nowhere we just get null.
            ActionMapping mapping = this.get_link_mapping_by_coordinates(e.x, e.y);

            if (mapping == null) {
                return false;
            }

            return mapping.on_button_press(source, e);
        }

        /**
         * Called whenever the mouse is moved on the surface of the View.Pdf
         *
         * The signal emitted by this method may for example be used to change
         * the mouse cursor if the pointer enters or leaves a link
         */
        protected bool on_mouse_move(Gtk.Widget source, Gdk.EventMotion event) {
            ActionMapping link_mapping = this.get_link_mapping_by_coordinates(event.x, event.y);

            if (link_mapping != this.active_mapping) {
                if (this.active_mapping != null) {
                    this.active_mapping.on_mouse_leave(source, event);
                }

                if (link_mapping != null) {
                    link_mapping.on_mouse_enter(source, event);
                }
            }
            this.active_mapping = link_mapping;

            return false;
        }

        /**
         * Handle newly entered pdf pages to create a link mapping table for
         * further requests and checks.
         */
        public void on_entering_slide(View.Pdf source, int page_number) {
            // Get the link mapping table
            bool in_range = true;
            Metadata.Pdf metadata = source.get_renderer().metadata;
            if (page_number < metadata.get_slide_count()) {
                this.page_link_mappings = metadata.get_action_mapping(page_number);
            } else {
                this.page_link_mappings = null;
                in_range = false;
            }
            if (!in_range) {
                return;
            }

            // Precalculate the a Gdk.Rectangle for every link mapping area
            if (this.page_link_mappings.size > 0) {
                this.precalculated_mapping_rectangles = new Gdk.Rectangle[this.page_link_mappings.size];
                int i = 0;
                foreach(var mapping in this.page_link_mappings) {
                    this.precalculated_mapping_rectangles[i++] = this.target.convert_poppler_rectangle_to_gdk_rectangle(
                        mapping.area
                    );
                }
            }
        }

        /**
         * Free the allocated link mapping tables, which were created on page
         * entering
         */
        public void on_leaving_slide(View.Pdf source, int from, int to) {
            // Free memory of precalculated rectangles
            this.precalculated_mapping_rectangles = null;
        }
    }
}
