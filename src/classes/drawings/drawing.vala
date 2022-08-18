/**
 * Classes to handle drawings over slides.
 *
 * This file is part of pdfpc.
 *
 * Copyright 2017 Charles Reiss
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

namespace pdfpc.Drawings {

    public class DrawingTool {
        public double red {get; set;}
        public double green {get; set;}
        public double blue {get; set;}
        public double alpha {get; set;}
        public double width {get; set;}
        public double pressure {get; set;}

        public bool is_eraser {get; set;}

        public Gdk.RGBA get_rgba() {
            Gdk.RGBA result = Gdk.RGBA();
            result.red = this.red;
            result.green = this.green;
            result.blue = this.blue;
            result.alpha= this.alpha;
            return result;
        }

        public void set_rgba(Gdk.RGBA color) {
            this.red = color.red;
            this.green = color.green;
            this.blue = color.blue;
            this.alpha = color.alpha;
        }

        public DrawingTool() {
            this.red = 1.0;
            this.green = 0.0;
            this.blue = 0.0;
            this.alpha = 1.0;
            this.width = 1.0;
            this.pressure = -1.0;
            this.is_eraser = false;
        }

        public void add_line(Cairo.Context context, double x1, double y1, double x2, double y2) {
            if (this.is_eraser) {
                context.set_operator(Cairo.Operator.CLEAR);
            } else {
                context.set_operator(Cairo.Operator.OVER);
                context.set_source_rgba(this.red, this.green, this.blue, this.alpha);
            }
            double lwidth = this.width;
            if (this.pressure >= 0.0) {
                // TODO: perhaps make this normalization adjustable
                // and/or implement a smarter mapping
                lwidth *= this.pressure/0.5;
            }
            context.set_line_width(lwidth);
            context.set_line_cap(Cairo.LineCap.ROUND);
            context.move_to(x1, y1);
            context.line_to(x2, y2);
            context.stroke();
        }
    }

    public class Drawing : Object {
        public int width { get; protected set; }
        public int height { get; protected set; }
        private Cairo.ImageSurface? surface;
        private Cairo.Context context { get; protected set; }

        public DrawingTool pen {get; protected set;}
        public DrawingTool eraser {get; protected set;}

        private int current_slide {get; set;}
        private Drawings.Storage.Base storage {get; protected set;}

        private DrawingCommandList drawing_command_list;

        protected void set_surface(Cairo.ImageSurface surface) {
            this.surface = surface;
            this.context = new Cairo.Context(this.surface);
        }

        private void set_new_surface() {
            set_surface(new Cairo.ImageSurface(Cairo.Format.ARGB32, this.width, this.height));
        }

        public Drawing(Drawings.Storage.Base storage, int width, int height) {
            this.storage = storage;
            this.width = width;
            this.height = height;

            this.pen = new DrawingTool();
            this.pen.width = this.width / 640.0;
            this.eraser = new DrawingTool();
            this.eraser.is_eraser = true;
            this.eraser.red = this.eraser.blue = this.eraser.green = 0;
            this.eraser.width = this.width / 64.0;

            this.current_slide == -1;

            this.set_new_surface();

            this.drawing_command_list = new DrawingCommandList();
        }

        public Cairo.ImageSurface? render_to_surface() {
            return this.surface;
        }

        /*
         * Draw a line from (x1, y1) to (x2, y2).
         * x and y coordinates are always in range [0, 1].
         */
        public void add_line(DrawingTool tool, double x1, double y1, double x2, double y2) {
            tool.add_line(this.context,
                x1 * this.width, y1 * this.height,
                x2 * this.width, y2 * this.height
            );

            // Copy the calculation from tool_add line. This calculation
            // should be shared.
            double lwidth = tool.width / this.width;
            if (tool.pressure >= 0.0) {
                // TODO: perhaps make this normalization adjustable
                // and/or implement a smarter mapping
                lwidth *= tool.pressure/0.5;
            }


            // Add to the drawing command list
            this.drawing_command_list.add_line(
                tool.is_eraser,
                x1, y1, x2, y2,
                lwidth,
                tool.red, tool.green, tool.blue, tool.alpha);
        }

        /*
         * Clear the current drawing.
         */
        public void clear() {
            this.context.set_operator(Cairo.Operator.CLEAR);
            this.context.paint();
            this.context.set_operator(Cairo.Operator.OVER);
            this.drawing_command_list.clear();
        }

        /*
         * Undo the last commands
         */
        public void undo() {
            this.drawing_command_list.undo();
            this.drawing_command_list.paint_in_surface(this.surface);
        }

        /*
         * Undo the last commands
         */
        public void redo() {
            this.drawing_command_list.redo();
            this.drawing_command_list.paint_in_surface(this.surface);
        }

        /*
         * Switch to a user slide, based on its number; all slides in an
         * overlay set share the same drawing.
         */
        public void switch_to_slide(int slide_number) {
            if (slide_number != this.current_slide) {
                if (this.surface != null) {
                    storage.store(this.current_slide, this.drawing_command_list);
                }

                this.drawing_command_list = storage.retrieve(slide_number);
                if (this.drawing_command_list == null) {
                    this.drawing_command_list = new DrawingCommandList();
                }
                set_new_surface();
                this.drawing_command_list.paint_in_surface(this.surface);
                this.current_slide = slide_number;
            }
        }

        /*
         * Clear the storage.
         */
        public void clear_storage() {
            this.storage.clear();
        }
    }

    /*
     * We don't need pixel-to-pixel accuracy for drawings; so just take the
     * PDF page size (in pt), and scale it up/down to have 1280 pixels in width.
     */
    public Drawing create(Metadata.Pdf metadata) {
        const double desired_width = 1280;
        double page_width = metadata.get_page_width();
        double page_height = metadata.get_page_height();
        if (page_width <= 0.0 || page_height <= 0.0) {
            page_height = desired_width;
        } else {
            page_height = (desired_width/page_width)*page_height;
        }
        page_width = desired_width;

        Drawings.Storage.Base storage = Drawings.Storage.create(metadata);
        return new Drawing(storage, (int) page_width, (int) page_height);
    }
}

