/**
 * Scaling calculator
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

using GLib;
using Gdk;

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Scaling calculator which is able to calculate different scaling
     * scenarios while maintaining the correct aspect ratio.
     */
    public class Scaler: Object {
        /**
         * The initial input width
         */
        protected double initial_width;

        /**
         * The initial input height
         */
        protected double initial_height;

        /**
         * Create a new Scaler taking initial width and height as input
         */
        public Scaler( double width, double height ) {
            this.initial_width = width;
            this.initial_height = height;
        }

        /**
         * Scale the initial dimensions to a specific measurement.
         *
         * The result is a Gdk.Rectangle, as by default the aspect_ration is
         * maintained and the result is centered in the given space.
         *
         * By default the given scaling will not cut off any information of the
         * source size. The allow_cutoff parameter allows to maximize usage of
         * the given space by allowing to cut off certain parts of the initial
         * input.
         */
        public Rectangle scale_to( int width, int height, bool centered = true, bool allow_cutoff = false ) {
            Rectangle target = Rectangle();
            double factor = 1.0f;
            if ( allow_cutoff == true ) {
                factor = Math.fmax( 
                    width / this.initial_width,
                    height / this.initial_height
                );
            }
            else {
                factor = Math.fmin( 
                    width / this.initial_width,
                    height / this.initial_height
                );
            }

            target.width  = (int)Math.floor( this.initial_width * factor );
            target.height = (int)Math.floor( this.initial_height * factor );

            if ( centered == true ) {
                target.x = (int)Math.floor( ( width - target.width ) / 2.0f );
                target.y = (int)Math.floor( ( height - target.height ) / 2.0f );
            }

            return target;
        }
    }
}
