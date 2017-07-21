/**
 * Classes to handle drawings over slides.
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2012, 2015 Andreas Bilke
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

    public class Drawing : Object {
        public int width { get; protected set; }
        public int height { get; protected set; }
        private Cairo.ImageSurface surface { get; protected set; }
        private Cairo.Context context { get; protected set; }

        public double pen_red {get; set;}
        public double pen_green {get; set;}
        public double pen_blue {get; set;}
        public double pen_alpha {get; set;}
        private double pen_width {get; set;}

        public double pen_width_on(int actual_width) {
            return this.pen_width * actual_width;
        }

        public Drawing(int width, int height) {
            this.width = width;
            this.height = height;

            this.surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, this.width, this.height);
            this.pen_red = 1.0;
            this.pen_green = 0.0;
            this.pen_blue = 0.0;
            this.pen_alpha = 1.0;
            this.pen_width = 1.0 / 640.0;
            this.context = new Cairo.Context(this.surface);
            this.context.set_operator(Cairo.Operator.OVER);
        }

        public Cairo.ImageSurface render_to_surface() {
            return this.surface;
        }

        // FIXME: should do smoother drawing?
        // x and y are always in range [0, 1]
        public void add_line(double x1, double y1, double x2, double y2) {
            this.context.set_source_rgba(this.pen_red, this.pen_green, this.pen_blue, this.pen_alpha);
            this.context.set_line_width(this.pen_width * width);
            this.context.move_to(x1 * this.width, y1 * this.height);
            this.context.line_to(x2 * this.width, y2 * this.height);
            this.context.stroke();
        }

        public void clear() {
            this.context.set_operator(Cairo.Operator.CLEAR);
            this.context.paint();
            this.context.set_operator(Cairo.Operator.OVER);
        }
    }
}

