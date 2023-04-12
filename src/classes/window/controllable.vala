/**
 * Fullscreen Window
 *
 * This file is part of pdfpc.
 *
 * Copyright 2010-2011 Jakob Westhoff
 * Copyright 2011,2012 David Vilar
 * Copyright 2012,2015 Robert Schroll
 * Copyright 2014,2016 Andy Barry
 * Copyright 2015,2017 Andreas Bilke
 * Copyright 2023 Evgeny Stambulchik
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

namespace pdfpc.Window {
    public class ControllableWindow : Fullscreen, Controllable {

        /**
         * The registered PresentationController
         */
        public PresentationController controller {
            get; protected set;
        }

        /**
         * Metadata of the slides
         */
        protected Metadata.Pdf metadata {
            get {
                return this.controller.metadata;
            }
        }

        public View.Pdf main_view { get; protected set; }

        /**
         * Whether the instance is presenter
         */
        public bool is_presenter {
            get; protected set;
        }

        /**
         * Overlay layout. Holds all drawing layers (main_view,
         * pointer & pen drawing areas, and the video surface)
         */
        protected Gtk.Overlay overlay_layout;

        /**
         * Drawing area for pointer mode
         */
        public Gtk.DrawingArea pointer_drawing_surface { get; protected set; }

        /**
         * Drawing area for pen mode
         */
        public Gtk.DrawingArea pen_drawing_surface { get; protected set; }

        /**
         * Video area for playback. All videos are added to this surface.
         */
        public View.Video video_surface { get; protected set; }

        /**
         * Timer id monitoring mouse motion to hide the cursor on main_view
         * after a few seconds of inactivity
         */
        protected uint hide_cursor_timeout = 0;

       /**
         * Base constructor instantiating a new controllable window
         */
        public ControllableWindow(PresentationController controller,
            bool is_presenter, int monitor_num, bool windowed,
            int width = -1, int height = -1) {

            base(monitor_num, windowed, width, height);
            this.controller = controller;

            this.title = "pdfpc - %s (%s)".printf(
                is_presenter ? "presenter" : "presentation",
                metadata.get_title());

            this.is_presenter = is_presenter;

            this.overlay_layout = new Gtk.Overlay();

            this.main_view = new View.Pdf.from_controllable_window(this,
                false, true);

            this.pointer_drawing_surface = new Gtk.DrawingArea();
            this.pen_drawing_surface = new Gtk.DrawingArea();
            this.video_surface = new View.Video();

            this.overlay_layout.add(this.main_view);
            this.overlay_layout.add_overlay(this.video_surface);
            this.overlay_layout.add_overlay(this.pen_drawing_surface);
            this.overlay_layout.add_overlay(this.pointer_drawing_surface);

            this.pointer_drawing_surface.no_show_all = true;
            this.pen_drawing_surface.no_show_all = true;

            this.video_surface.realize.connect(() => {
                this.set_widget_event_pass_through(this.video_surface, true);
            });
            this.pen_drawing_surface.realize.connect(() => {
                this.pen_drawing_surface.get_window().set_pass_through(true);
                this.set_widget_event_pass_through(this.pen_drawing_surface,
                    true);
            });
            this.pointer_drawing_surface.realize.connect(() => {
                this.pointer_drawing_surface.get_window().set_pass_through(true);
                this.set_widget_event_pass_through(this.pointer_drawing_surface,
                    true);
            });

            this.add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            this.motion_notify_event.connect(this.on_mouse_move);

            this.pointer_drawing_surface.draw.connect(this.draw_pointer);
            this.pen_drawing_surface.draw.connect(this.draw_pen);

            this.key_press_event.connect(this.controller.key_press);
            this.button_press_event.connect(this.controller.button_press);
            this.scroll_event.connect(this.controller.scroll);

            this.controller.zoom_request.connect(this.on_zoom);

            this.controller.reload_request.connect(this.on_reload);

            // Start the 5 seconds timeout after which the mouse cursor is
            // hidden
            this.restart_hide_cursor_timer();

            this.destroy.connect((source) => controller.quit());
        }

        /**
         * Set the widget passthrough.
         *
         * If set to true, the widget will not receive events and they will be
         * forwarded to the underlying widgets within the Gtk.Overlay
         */
        protected void set_widget_event_pass_through(Gtk.Widget w,
            bool pass_through) {
            this.overlay_layout.set_overlay_pass_through(w, pass_through);
        }

        protected bool draw_pointer(Cairo.Context context) {
            Gtk.Allocation a;
            this.pointer_drawing_surface.get_allocation(out a);
            PresentationController c = this.controller;

            // Draw the highlighted area, but ignore very short drags
            // made unintentionally by mouse clicks
            if (!c.current_pointer.is_spotlight &&
                c.highlight.width > 0.01 && c.highlight.height > 0.01) {
                context.rectangle(0, 0, a.width, a.height);
                context.new_sub_path();
                context.rectangle((int)(c.highlight.x*a.width),
                                  (int)(c.highlight.y*a.height),
                                  (int)(c.highlight.width*a.width),
                                  (int)(c.highlight.height*a.height));

                context.set_fill_rule(Cairo.FillRule.EVEN_ODD);
                context.set_source_rgba(0,0,0,0.5);
                context.fill_preserve();

                context.new_path();
            }
            // Draw the pointer when not dragging
            if (c.drag_x == -1 &&
                (!c.pointer_hidden || c.current_pointer.is_spotlight)) {
                int x = (int)(a.width*c.pointer_x);
                int y = (int)(a.height*c.pointer_y);
                int r = (int)(a.height*0.001*c.current_pointer.size);

                Gdk.RGBA rgba = c.current_pointer.get_rgba();
                context.set_source_rgba(rgba.red,
                                        rgba.green,
                                        rgba.blue,
                                        rgba.alpha);
                if (c.current_pointer.is_spotlight) {
                    context.rectangle(0, 0, a.width, a.height);
                    context.new_sub_path();
                    context.set_fill_rule(Cairo.FillRule.EVEN_ODD);
                }
                context.arc(x, y, r, 0, 2*Math.PI);
                context.fill();
            }

            return true;
        }

        public void enable_pointer(bool onoff) {
            if (onoff) {
                this.pointer_drawing_surface.show();
            } else {
                this.pointer_drawing_surface.hide();
            }
        }

        protected bool draw_pen(Cairo.Context context) {
            Gtk.Allocation a;
            this.pen_drawing_surface.get_allocation(out a);
            PresentationController c = this.controller;

            if (c.pen_drawing != null) {
                Cairo.Surface? drawing_surface =
                    c.pen_drawing.render_to_surface();
                int x = (int)(a.width*c.pen_last_x);
                int y = (int)(a.height*c.pen_last_y);
                int base_width = c.pen_drawing.width;
                int base_height = c.pen_drawing.height;
                Cairo.Matrix old_xform = context.get_matrix();
                context.scale(
                    (double) a.width / base_width,
                    (double) a.height / base_height
                );
                context.set_source_surface(drawing_surface, 0, 0);
                context.paint();
                context.set_matrix(old_xform);
                if (this.is_presenter && c.in_drawing_mode() &&
                    !c.pointer_hidden) {
                    double width_adjustment = (double) a.width / base_width;
                    context.set_operator(Cairo.Operator.OVER);
                    context.set_line_width(2.0);
                    context.set_source_rgba(
                        c.current_pen_drawing_tool.red,
                        c.current_pen_drawing_tool.green,
                        c.current_pen_drawing_tool.blue,
                        1.0
                    );
                    double arc_radius =
                        c.current_pen_drawing_tool.width*width_adjustment/2.0;
                    if (arc_radius < 1.0) {
                        arc_radius = 1.0;
                    }
                    context.arc(x, y, arc_radius, 0, 2*Math.PI);
                    context.stroke();
                }
            }

            return true;
        }

        public void enable_pen(bool onoff) {
            if (onoff) {
                this.pen_drawing_surface.show();
            } else {
                this.pen_drawing_surface.hide();
            }
        }

        /**
         * Called every time the mouse cursor is moved
         */
        public bool on_mouse_move(Gtk.Widget source, Gdk.EventMotion event) {
            // Restore the mouse cursor to its default value
            this.get_window().set_cursor(null);

            this.restart_hide_cursor_timer();

            return false;
        }
        /**
         * Restart the 5 seconds timeout before hiding the mouse cursor
         */
        protected void restart_hide_cursor_timer(){
            if (this.hide_cursor_timeout != 0) {
                Source.remove(this.hide_cursor_timeout);
            }

            this.hide_cursor_timeout = Timeout.add_seconds(5,
                this.on_hide_cursor_timeout);
        }

        /**
         * Timeout method called if the mouse pointer has not been moved for 5
         * seconds
         */
        protected bool on_hide_cursor_timeout() {
            this.hide_cursor_timeout = 0;

            // Window might be null in case it has not been mapped
            if (this.get_window() != null) {
                var cursor =
                    new Gdk.Cursor.for_display(Gdk.Display.get_default(),
                        Gdk.CursorType.BLANK_CURSOR);
                this.get_window().set_cursor(cursor);

                // After the timeout disabled the cursor do not run it again
                return false;
            } else {
                // The window was not available. Possibly it was not mapped
                // yet. We simply try it again if the mouse isn't moved for
                // another five seconds.
                return true;
            }
        }

        /**
         * Called on document reload.
         * TODO: in principle the document geometry may change!
         */
        private void on_reload() {
            this.main_view.invalidate();
        }

        private void on_zoom(PresentationController.ScaledRectangle? rect) {
            this.main_view.display(this.controller.current_slide_number,
                true, rect);
        }
    }
}
