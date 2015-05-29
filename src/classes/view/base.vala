/**
 * Slide View
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2015 Robert Schroll
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
     * Base class for every slide view
     */
    public abstract class View.Base : Gtk.DrawingArea {
        /**
         * Signal fired every time a slide is about to be left
         */
        public signal void leaving_slide(int from, int to);

        /**
         * Signal fired every time a slide is entered
         */
        public signal void entering_slide(int slide_number);

        /**
         * Renderer to be used for rendering the slides
         */
        protected Renderer.Base renderer;

        /**
         * Base constructor taking the renderer to use as an argument
         */
        protected Base( Renderer.Base renderer ) {
            this.renderer = renderer;
            this.set_size_request(renderer.width, renderer.height);
        }

        /**
         * Return the used renderer object
         */
        public Renderer.Base get_renderer() {
            return this.renderer;
        }

        /**
         * Display a specific slide
         *
         * If the slide number does not exist a RenderError.SLIDE_DOES_NOT_EXIST is thrown
         */
        public abstract void display(int slide_number, bool force_redraw=false)
            throws Renderer.RenderError;

        /**
         * Make the screen black. Useful for presentations together with a whiteboard
         */
        public abstract void fade_to_black();

        /**
         * Redraw the current slide. Useful for example when exiting from fade_to_black
         */
        public abstract void redraw() throws Renderer.RenderError;

        /**
         * Return the currently shown slide number
         */
        public abstract int get_current_slide_number();
    }
}

