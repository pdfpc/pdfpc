/**
 * Controllable Fullscreen-capable Window
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
        public PresentationController controller { get; protected set; }

        /**
         * The main view widget
         */
        public View.Pdf main_view { get; protected set; }

        /**
         * Metadata of the slides
         */
        protected Metadata.Pdf metadata {
            get {
                return this.controller.metadata;
            }
        }

        /**
         * Whether the user directly interacts with this window
         */
        public bool interactive { get; protected set; }

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
         * Overlay layout. Holds all drawing layers (main_view,
         * pointer & pen drawing areas, and the video surface)
         */
        protected Gtk.Overlay overlay_layout;

        /**
         * Timer id monitoring mouse motion to hide the cursor on main_view
         * after a few seconds of inactivity
         */
        protected uint hide_cursor_timeout = 0;

        /**
         * Cursor state kept internally
         */
        protected bool cursor_blanked = false;

        /**
         * Key modifiers that we support
         */
        protected uint accepted_key_mods = Gdk.ModifierType.SHIFT_MASK   |
                                           Gdk.ModifierType.CONTROL_MASK |
                                           Gdk.ModifierType.META_MASK;

        /**
         * Timestamp of the last key event
         */
        protected uint last_key_ev_time = 0;

       /**
         * Base constructor instantiating a new controllable window
         */
        public ControllableWindow(PresentationController controller,
            bool interactive, int monitor_num, bool windowed,
            int width = -1, int height = -1) {

            base(monitor_num, windowed, width, height);
            this.controller = controller;

            this.interactive = interactive;

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

            // Soft cursor drawing events
            this.pointer_drawing_surface.draw.connect(this.draw_pointer);
            this.pen_drawing_surface.draw.connect(this.draw_pen);

            // Special events coming from the controller
            this.controller.zoom_request.connect(this.c_on_zoom);
            this.controller.reload_request.connect(this.c_on_reload);

            // Start the timeout after which the mouse cursor gets hidden
            this.restart_hide_cursor_timer();

            this.destroy.connect((source) => controller.quit());
        }

        protected void add_top_container(Gtk.Widget top) {
            this.add(top);
            if (this.interactive) {
                this.register_presenter_handlers(top);
            }
        }

        public void enable_pointer(bool onoff) {
            if (onoff) {
                this.pointer_drawing_surface.show();
            } else {
                this.pointer_drawing_surface.hide();
            }
        }

        public void enable_pen(bool onoff) {
            if (onoff) {
                this.pen_drawing_surface.show();
            } else {
                this.pen_drawing_surface.hide();
            }
        }

        protected void register_presenter_handlers(Gtk.Widget top) {
            // Main view events
            var view = this.main_view;
            view.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK |
                            Gdk.EventMask.LEAVE_NOTIFY_MASK);

            view.motion_notify_event.connect(this.v_on_mouse_move);
            view.enter_notify_event.connect(this.v_on_enter_notify);
            view.leave_notify_event.connect(this.v_on_leave_notify);
            view.button_press_event.connect(this.v_on_button_press);
            view.button_release_event.connect(this.v_on_button_release);

            // General controlling events acting on the whole window
            this.key_press_event.connect(this.w_on_key_press);

            this.add_events(Gdk.EventMask.SCROLL_MASK);
            this.scroll_event.connect(this.w_on_scroll);

            // Wayland treats the window decorations as part of the window.
            // Thus, we assign the mouse handler to the top widget instead,
            // so the WM actions like resize & drag continue working.
            top.button_press_event.connect(this.w_on_button_press);
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
                if (this.interactive && c.in_drawing_mode() &&
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

        /**
         * Handle keypresses
         */
        protected bool w_on_key_press(Gdk.EventKey key) {
            if (key.time != last_key_ev_time) {
                last_key_ev_time = key.time;

                // Punctuation characters are usually generated by keyboards
                // with the Shift mod pressed; we ignore it in this case.
                if (((char) key.keyval).ispunct()) {
                    key.state &= ~Gdk.ModifierType.SHIFT_MASK;
                }
                var keydef = new KeyDef(key.keyval,
                    key.state & this.accepted_key_mods);

                return controller.on_key_press(keydef);
            } else {
                return false;
            }
        }

        /**
         * Handle mouse clicks
         */
        protected bool w_on_button_press(Gdk.EventButton button) {
            if (button.type == Gdk.EventType.BUTTON_PRESS) {
                var keydef = new KeyDef(button.button,
                    button.state & this.accepted_key_mods);
                return controller.on_button_press(keydef);
            } else {
                return false;
            }
        }

        /**
         * Handle mouse scrolling
         */
        protected bool w_on_scroll(Gdk.EventScroll scroll) {
            bool up = false, down = false;

            switch (scroll.direction) {
            case Gdk.ScrollDirection.UP:
            case Gdk.ScrollDirection.LEFT:
                up = true;
                break;
            case Gdk.ScrollDirection.DOWN:
            case Gdk.ScrollDirection.RIGHT:
                down = true;
                break;
            case Gdk.ScrollDirection.SMOOTH:
                double dx, dy;
                scroll.get_scroll_deltas(out dx, out dy);
                if (dx > 0 || dy > 0) {
                    down = true;
                } else if (dx < 0 || dy < 0) {
                    up = true;
                }
                break;
            default:
                break;
            }

            if (up) {
                return controller.on_scroll(true, scroll.state);
            } else if (down) {
                return controller.on_scroll(false, scroll.state);
            } else {
                return false;
            }
        }

        /**
         * Called every time the mouse is moved
         */
        protected bool v_on_mouse_move(Gtk.Widget source, Gdk.EventMotion event) {
            // If the cursor is blanked, restore it to its default value
            if (this.cursor_blanked) {
                event.window.set_cursor(null);
                this.cursor_blanked = false;
            }

            this.restart_hide_cursor_timer();

            // We always update the soft pointer position, even if hidden.
            // Otherwise, the pointer will appear at the old position
            // when it is first shown and jump at the next mouse move.
            this.device_to_normalized(event.x, event.y,
                out controller.pointer_x, out controller.pointer_y);

            if (controller.in_pointing_mode()) {
                return controller.on_move_pointer();
            } else if (controller.in_drawing_mode()) {
                var dev = event.get_source_device();
                if (!Options.disable_input_autodetection) {
                    Gdk.InputSource source_type = dev.get_source();
                    if (source_type == Gdk.InputSource.ERASER) {
                        var mode = PresentationController.AnnotationMode.ERASER;
                        controller.set_mode(mode);
                    } else if (source_type == Gdk.InputSource.PEN) {
                        var mode = PresentationController.AnnotationMode.PEN;
                        controller.set_mode(mode);
                    }
                }

                if (!Options.disable_input_pressure &&
                    controller.pen_is_pressed) {
                    double pressure;
                    if (dev.get_axis(event.axes, Gdk.AxisUse.PRESSURE,
                        out pressure) != true) {
                        pressure = -1.0;
                    }
                    controller.set_pen_pressure(pressure);
                }

                return controller.on_move_pen();
            } else {
                return false;
            }
        }

        protected bool v_on_enter_notify() {
            return controller.on_enter_notify();
        }

        protected bool v_on_leave_notify() {
            return controller.on_leave_notify();
        }

        protected bool v_on_button_press(Gdk.EventButton event) {
            if (controller.is_pointer_active()) {
                this.device_to_normalized(event.x, event.y,
                    out controller.drag_x, out controller.drag_y);
                controller.highlight.width = 0;
                controller.highlight.height = 0;
                return true;
            } else if (controller.in_drawing_mode()) {
                double x, y;
                this.device_to_normalized(event.x, event.y, out x, out y);
                controller.move_pen(x, y);
                controller.pen_is_pressed = true;
                return true;
            } else {
                return false;
            }
        }

        protected bool v_on_button_release(Gdk.EventButton event) {
            if (controller.is_pointer_active()) {
                double x, y;
                this.device_to_normalized(event.x, event.y, out x, out y);
                controller.update_highlight(x, y);
                controller.drag_x = -1;
                controller.drag_y = -1;
                return true;
            } else if (controller.in_drawing_mode()) {
                double x, y;
                this.device_to_normalized(event.x, event.y, out x, out y);
                controller.move_pen(x, y);
                controller.pen_is_pressed = false;
                return true;
            } else {
                return false;
            }
        }

        /**
         * Restart the timeout before hiding the mouse cursor
         */
        protected void restart_hide_cursor_timer(){
            if (this.hide_cursor_timeout != 0) {
                Source.remove(this.hide_cursor_timeout);
            }

            this.hide_cursor_timeout =
                Timeout.add_seconds(Options.cursor_timeout,
                this.on_hide_cursor_timeout);
        }

        /**
         * Timeout method called if the mouse pointer has not been moved for
         * a while
         */
        protected bool on_hide_cursor_timeout() {
            this.hide_cursor_timeout = 0;
            var w = this.main_view.get_window();

            // Window might be null in case it has not been mapped
            if (w != null) {
                var cursor =
                    new Gdk.Cursor.for_display(Gdk.Display.get_default(),
                        Gdk.CursorType.BLANK_CURSOR);
                w.set_cursor(cursor);
                this.cursor_blanked = true;

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
        protected void c_on_reload() {
            this.main_view.invalidate();
        }

        protected void c_on_zoom(PresentationController.ScaledRectangle? rect) {
            this.main_view.display(this.controller.current_slide_number,
                true, rect);
        }

        /**
         * Convert device coordinates to normalized ones
         */
        protected void device_to_normalized(double dev_x, double dev_y,
            out double x, out double y) {
            Gtk.Allocation a;
            this.main_view.get_allocation(out a);

            x = dev_x/a.width;
            y = dev_y/a.height;
        }
    }
}
