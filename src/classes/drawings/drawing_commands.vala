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
            this.drawing_commands = new List<DrawingCommand?>();
            this.redo_commands = new List<DrawingCommand?>();
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
            this.redo_commands = new List<DrawingCommand?>(); // clear

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

            this.paint_on_context(cr, surface.get_width(), surface.get_height());
        }

        public void paint_on_context(Cairo.Context cr, int width, int height) {
            // Default settings
            cr.set_operator(Cairo.Operator.OVER);
            cr.set_source_rgba(1, 0, 0, 1);
            cr.set_line_width(5);
            cr.set_line_cap(Cairo.LineCap.ROUND);
            cr.set_line_join(Cairo.LineJoin.ROUND);

            // Loop over commands and carry them out
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

        public void occupied_rect(out double x1, out double y1, out double x2, out double y2) {
            double min_x = 1.0, min_y = 1.0, max_x = 0.0, max_y = 0.0;

            foreach (var dc in this.drawing_commands) {
                if (dc.is_eraser) {
                    continue;
                }

                // XXX: this isn't correct for all aspect ratios (because the line width isn't stretched)
                min_x = Math.fmin(Math.fmin(dc.x1, dc.x2) - dc.lwidth, min_x);
                min_y = Math.fmin(Math.fmin(dc.y1, dc.y2) - dc.lwidth, min_y);
                max_x = Math.fmax(Math.fmax(dc.x1, dc.x2) + dc.lwidth, max_x);
                max_y = Math.fmax(Math.fmax(dc.y1, dc.y2) + dc.lwidth, max_y);
            }

            x1 = Math.fmax(min_x, 0.0);
            y1 = Math.fmax(min_y, 0.0);
            x2 = Math.fmin(max_x, 1.0);
            y2 = Math.fmin(max_y, 1.0);
        }

        public void serialize(Json.Builder builder) {
            if (this.drawing_commands.is_empty()) {
                return;
            }

            var sb = new StringBuilder();
            size_t i = 0;
            foreach (var dc in this.drawing_commands) {
                if (dc.new_path) {
                    if (i != 0) {
                        sb.append_c(' ');
                        sb.append(dc.x2.to_string());
                        sb.append_c(' ');
                        sb.append(dc.y2.to_string());
                        sb.append_c(' ');
                        sb.append(dc.lwidth.to_string());
                        builder.add_string_value(sb.free_and_steal());
                        sb = new StringBuilder();
                        builder.end_object();
                    }
                    builder.begin_object();
                    builder.set_member_name("is_eraser");
                    builder.add_boolean_value(dc.is_eraser);
                    builder.set_member_name("red");
                    builder.add_double_value(dc.red);
                    builder.set_member_name("green");
                    builder.add_double_value(dc.green);
                    builder.set_member_name("blue");
                    builder.add_double_value(dc.blue);
                    builder.set_member_name("alpha");
                    builder.add_double_value(dc.alpha);
                    builder.set_member_name("path");
                } else {
                    sb.append_c(' ');
                }
                sb.append(dc.x1.to_string());
                sb.append_c(' ');
                sb.append(dc.y1.to_string());
                sb.append_c(' ');
                sb.append(dc.lwidth.to_string());
                i++;
            }

            unowned var last = this.drawing_commands.last().data;
            sb.append_c(' ');
            sb.append(last.x2.to_string());
            sb.append_c(' ');
            sb.append(last.y2.to_string());
            sb.append_c(' ');
            sb.append(last.lwidth.to_string());
            builder.add_string_value(sb.free_and_steal());
            builder.end_object();
        }

        public void deserialize(Json.Array content) {
            for (uint i = 0; i < content.get_length(); i++) {
                unowned var path = content.get_object_element(i);
                var is_eraser = path.get_boolean_member("is_eraser");
                var red = path.get_double_member("red");
                var green = path.get_double_member("green");
                var blue = path.get_double_member("blue");
                var alpha = path.get_double_member("alpha");
                unowned var str = path.get_string_member("path");
                if (str.length < 5) {
                    continue;
                }
                
                bool initial = true;
                while (str.data[0] != '\0') {
                    unowned string end;
                    double x1 = 0.0;
                    double y1 = 0.0;
                    double lwidth = 0.0;
                    // A point is defined like "{x1} {x2} {lwidth}" with a 
                    // space or null terminator afterwards.
                    double.try_parse(str, out x1, out end);
                    if (str == end) {
                        break;
                    }
                    str = end.offset(1);
                    double.try_parse(str, out y1, out end);
                    if (str == end) {
                        break;
                    }
                    str = end.offset(1);
                    double.try_parse(str, out lwidth, out end);
                    if (str == end) {
                        break;
                    }
                    if (end.data[0] != '\0') {
                        str = end.offset(1);
                    }

                    if (!initial) {
                        unowned var last = this.drawing_commands.last().data;
                        last.x2 = x1;
                        last.y2 = y1;
                    }
                    this.drawing_commands.append(DrawingCommand() {
                        new_path = initial,
                        is_eraser = is_eraser,
                        red = red,
                        green = green,
                        blue = blue,
                        alpha = alpha,
                        x1 = x1,
                        y1 = y1,
                        lwidth = lwidth
                    });

                    initial = false;
                }

                // The last point we receive in a path only sets {x,y}2 but
                // doesn't define a new command.
                if (this.drawing_commands.length() >= 2) {
                    this.drawing_commands.remove_link(this.drawing_commands.last());
                }
            }
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

