/**
 * Prerendering interface
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

namespace org.westhoffswelt.pdfpresenter.View {
    /**
     * Every View may implement this interface to allow prerendering of slides
     * for display speed improvements. If however a renderer is used with the
     * view, which does not implement the Renderer.Caching interface the
     * prerender functionallity can't be used.
     */
    public interface Prerendering: GLib.Object {
        /**
         * Signal emitted every time a precached slide has been created
         *
         * This signal should be emitted slide_count number of times during a
         * precaching cylce.
         */
        public signal void slide_prerendered();

        /**
         * Signal emitted when the precaching cycle is complete
         */
        public signal void prerendering_completed();

        /**
         * Signal emitted when the precaching cycle just started
         */
        public signal void prerendering_started();
    }
}
