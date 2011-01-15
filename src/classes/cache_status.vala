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
     * Status widget showing the fill status of all registered pdf image caches
     */
    public class CacheStatus: Gtk.Image
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
         * Width of the widget
         */
        protected int width = 0;

        /**
         * Height of the widget
         */
        protected int height = 0;
        
        /**
         * Set the height of the widget
         */
        public void set_height( int height ) {
            this.height = height;
        }

        /**
         * Set the width of the widget
         */
        public void set_width( int width ) {
            this.width = width;
        }

        /**
         * Draw the current state to the widgets surface
         */
        public void redraw() {
            // Only draw if the widget is actually added to some parent
            if ( this.get_parent() == null ) {
                return;
            }

            Pixmap background_pixmap = new Pixmap(
                null,
                this.width,
                this.height,
                24
            );

            Context cr = Gdk.cairo_create( background_pixmap );
            
            cr.set_source_rgb( 0, 0, 0 );
            cr.rectangle( 0,0, this.width, this.height );
            cr.fill();

            cr.set_source_rgb( 1, 1, 1 );
            cr.rectangle( 
                0,
                0,
                (int)Math.ceil( this.width * ( (double)this.current_value / this.max_value ) ),
                this.height
            );
            cr.fill();

            this.set_from_pixmap( background_pixmap, null );
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
                this.redraw();
            });
        }
    }
}
