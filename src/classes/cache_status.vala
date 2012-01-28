/**
 * Cache status widget
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

using Gtk;
using Gdk;
using Cairo;

namespace org.westhoffswelt.pdfpresenter {
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
         * The function for updating the display with the current progress
         */
        public delegate void UpdateFunction(double progress);
        UpdateFunction? update_function = null;

        /**
         * The function to notify that we are finished
         */
        public delegate void UpdateComplete();
        UpdateComplete? update_complete = null;

        /**
         * Register the functions for updating
         */
        public void register_update(UpdateFunction update, UpdateComplete complete) {
            this.update_function = update;
            this.update_complete = complete;
        }
    
        /**
         * Draw the current state to the widgets surface
         */
        public void update() {
            // Only draw if the widget is actually added to some parent
            if (this.current_value == this.max_value) {
                if (update_complete != null)
                    update_complete();
            } else {
                if (update_function != null)
                    update_function((double)this.current_value / this.max_value);
            }
        }

        /**
         * Monitor a new view for prerendering information
         */
        public void monitor_view( View.Prerendering view ) {
            view.prerendering_started.connect( (v) => {
                this.max_value += (int)((View.Base)v).get_renderer().get_metadata().get_slide_count();
            });
            view.slide_prerendered.connect( () => {
                ++this.current_value;
                this.update();
            });
        }
    }
}
