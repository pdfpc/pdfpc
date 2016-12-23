/**
 * Cache status widget
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
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
     * Interface for showing the fill status of all registered pdf image caches
     */
    public class CacheStatus
    {
        /**
         * The number of entries currently inside the cache
         */
        protected int current_value = 0;

        /**
         * The value which indicates a fully primed cache
         */
        protected int max_value = 0;

        /**
         * The signal for updating the display with the current progress
         */
        public signal void update_progress(double progress);

        /**
         * The signal to notify that we are finished
         */
        public signal void update_complete();

        /**
         * Draw the current state to the widgets surface
         */
        public void update() {
            // Only draw if the widget is actually added to some parent
            if (this.current_value == this.max_value) {
                update_complete();
            } else {
                update_progress((double)this.current_value / this.max_value);
            }
        }

        /**
         * Monitor a new view for prerendering information
         */
        public void monitor_view( View.Pdf view ) {
            view.prerendering_started.connect( (v) => {
                this.max_value += (int)v.get_renderer().metadata.get_slide_count();
            });
            view.slide_prerendered.connect( () => {
                ++this.current_value;
                this.update();
            });
        }
    }
}
