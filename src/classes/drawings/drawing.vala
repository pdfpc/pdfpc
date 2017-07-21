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

    public class DrawingTool {
        public double red {get; set;}
        public double green {get; set;}
        public double blue {get; set;}
        public double alpha {get; set;}
        public double width {get; set;}

        public bool is_eraser {get; set;}
        
        public DrawingTool() {
            this.red = 1.0;
            this.green = 0.0;
            this.blue = 0.0;
            this.alpha = 1.0;
            this.width = 1.0;
            this.is_eraser = false;
        }

        public void add_line(Cairo.Context context, double x1, double y1, double x2, double y2) {
            if (this.is_eraser) {
                context.set_operator(Cairo.Operator.CLEAR);
            } else {
                context.set_operator(Cairo.Operator.OVER);
                context.set_source_rgba(this.red, this.green, this.blue, this.alpha);
            }
            context.set_line_width(this.width);
            context.move_to(x1, y1);
            context.line_to(x2, y2);
            context.stroke();
        }
    }

    public class Drawing : Object {
        public int width { get; protected set; }
        public int height { get; protected set; }
        private Cairo.ImageSurface surface { get; protected set; }
        private Cairo.Context context { get; protected set; }

        public DrawingTool pen {get; protected set;}
        public DrawingTool eraser {get; protected set;}


        public Drawing(int width, int height) {
            this.width = width;
            this.height = height;

            this.surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, this.width, this.height);
            this.pen = new DrawingTool();
            this.pen.width = this.width / 640.0;
            this.eraser = new DrawingTool();
            this.eraser.is_eraser = true;
            this.eraser.red = this.eraser.blue = this.eraser.green = 0;
            this.eraser.width = this.width / 64.0;
            this.context = new Cairo.Context(this.surface);
            this.context.set_operator(Cairo.Operator.OVER);
        }

        public Cairo.ImageSurface render_to_surface() {
            return this.surface;
        }

        // FIXME: should do smoother drawing?
        // x and y are always in range [0, 1]
        public void add_line(DrawingTool tool, double x1, double y1, double x2, double y2) {
            tool.add_line(this.context,
                x1 * this.width, y1 * this.height,
                x2 * this.width, y2 * this.height
            );
        }

        public void clear() {
            this.context.set_operator(Cairo.Operator.CLEAR);
            this.context.paint();
            this.context.set_operator(Cairo.Operator.OVER);
        }
    }
}

