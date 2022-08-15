/**
 * Classes to handle drawings over slides.
 *
 * This file is part of pdfpc.
 *
 * Copyright 2017 Charles Reiss
 * Copyright 2022 Dov Grobgeld <dov.grobgeld@gmail.com>
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

namespace pdfpc {

    // A drawing command is a cashed stroke with either a pen or
    // the eraser.
    public struct DrawingCommand {
        bool new_path;
        bool is_eraser;
        double x1;
        double y1;
        double x2;
        double y2;
        double lwidth;
        double red;
        double green;
        double blue;
        double alpha;
    }

    // A class for caching and replaying drawingcommands
    public class DrawingCommandList {
        public List<DrawingCommand?> drawing_commands;

        // The redo command list is manipulated by the undo and the
        // redo commands. Whenever a new DrawingCommand is added, the
        // redo is cleared (i.e. You can't redo if you've painted something
        // else. The list is stored in reverse order
        public List<DrawingCommand?> redo_commands;

        public DrawingCommandList() {
            clear();
        }

        public void clear() {
            this.drawing_commands = new List<DrawingCommand>();
            this.redo_commands = new List<DrawingCommand>();
        }

        public void add_line(bool is_eraser,
                             double x1, double y1, double x2, double y2,
                             double lwidth,
                             double red, double green, double blue,
                             double alpha) {
            // The new_path which is used for undo and redo is currently
            // done heuristically by checking if the previous command
            // is not of the same eraser type or the previous (x2,y2)
            // is different from the current (x1,y1)

            // After adding a new line you can no longer redo the old
            // path.
            this.redo_commands = new List<DrawingCommand>(); // clear

            bool new_path = true;
            double epsilon = 1e-4; // Less than 0.1 pixel for a 1000x1000 img
            if (drawing_commands != null) {
                var last = this.drawing_commands.last().data;
                if (is_eraser == last.is_eraser
                    && Math.fabs(last.x2-x1)<epsilon
                    && Math.fabs(last.y2-y1)<epsilon) {
                    new_path = false;
                }
            }

            var dc = DrawingCommand();
            dc.new_path = new_path;
            dc.is_eraser = is_eraser;
            dc.x1 = x1;
            dc.y1 = y1;
            dc.x2 = x2;
            dc.y2 = y2;
            dc.lwidth = lwidth;
            dc.red = red;
            dc.green = green;
            dc.blue = blue;
            dc.alpha = alpha;
            this.drawing_commands.append(dc);
        }

        // Paint the drawing commands in the surface
        public void paint_in_surface(Cairo.ImageSurface surface) {
            Cairo.Context cr = new Cairo.Context(surface);

            // Clear the surface
            cr.set_operator(Cairo.Operator.CLEAR);
            cr.paint();

            // Default settings
            cr.set_operator(Cairo.Operator.OVER);
            cr.set_source_rgba(1, 0, 0, 1);
            cr.set_line_width(5);
            cr.set_line_cap(Cairo.LineCap.ROUND);
            cr.set_line_join(Cairo.LineJoin.ROUND);

            // Loop over commands and carry them out
            int width = surface.get_width();
            int height = surface.get_height();
            drawing_commands.foreach((dc) => {
                if (dc.is_eraser) {
                    cr.set_operator(Cairo.Operator.CLEAR);
                } else {
                    cr.set_operator(Cairo.Operator.OVER);
                }

                cr.set_line_width(dc.lwidth * width);
                cr.set_source_rgba(dc.red,
                                   dc.green,
                                   dc.blue,
                                   dc.alpha);

                cr.move_to(dc.x1*width, dc.y1*height);
                cr.line_to(dc.x2*width, dc.y2*height);

                cr.stroke();
            });
        }

        public void undo() {
            // pop commands from the end of the drawing_command list
            // and put them on the redo list until a new_path is found.

            while (this.drawing_commands != null) {
                unowned var el = this.drawing_commands.last();
                DrawingCommand dc = el.data;
                this.drawing_commands.remove_link(el);
                this.redo_commands.append(dc);
                if (dc.new_path) {
                    break;
                }
            }
        }

        public void redo() {
            // pop commands from the end of the redo_command list
            // and put them on the drawing_command_list until a
            // new_path is found.

            bool first = true; // Allow the first command to be newpath
            while (this.redo_commands != null) {
                unowned var el = this.redo_commands.last();
                DrawingCommand dc = el.data;

                if (!first && dc.new_path) {
                    break;
                }
                first = false;
                this.redo_commands.remove_link(el);
                this.drawing_commands.append(dc);
            }
        }
    }
}

