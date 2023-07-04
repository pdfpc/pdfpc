/**
 * Presenter toolbox
 *
 * This file is part of pdfpc.
 *
  * Copyright 2017 Evgeny Stambulchik
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
    /**
     * Fixed layout - container of the toolbox
     */
    public class ToolBox : Gtk.Fixed {
        protected PresentationController controller;

        /**
         * The toolbox itself
         */
        protected Gtk.Box toolbox;

        /**
         * Drawing color selector button of the toolbox
         */
        protected Gtk.ColorButton color_button;

        /**
         * Drawing scale selector button of the toolbox
         */
        protected Gtk.ScaleButton scale_button;

        /**
         * Coordinates of the click event at the beginning of toolbox dragging
         **/
        private int x0;
        private int y0;

        /**
         * Size of the toolbox button icons
         **/
        private int icon_height;

        protected bool on_button_press(Gtk.Widget pbut, Gdk.EventButton event) {
            if (event.button == 1 ) {
                var w = this.get_parent().get_window();

                w.get_position(out this.x0, out this.y0);

                this.x0 += (int) event.x;
                this.y0 += (int) event.y;
            }

            return true;
        }

        protected bool on_move_pointer(Gtk.Widget pbut, Gdk.EventMotion event) {
            int x = (int) event.x_root - this.x0;
            int y = (int) event.y_root - this.y0;

            if (true) {
                int dest_x, dest_y;
                toolbox.translate_coordinates(pbut, x, y,
                    out dest_x, out dest_y);
                this.move(toolbox, dest_x, dest_y);
            }

            return true;
        }

        protected Gtk.Button add_button(Gtk.Box panel,
            bool tbox_inverse, string icon_fname, string? tooltip = null) {
            var bimage = load_icon(icon_fname, icon_height);
            bimage.show();
            var button = new Gtk.Button();
            button.add(bimage);
            button.can_focus = false;
            button.add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            if (!Options.disable_tooltips) {
                button.set_tooltip_text(tooltip);
            }
            if (tbox_inverse) {
                panel.pack_end(button);
            } else {
                panel.pack_start(button);
            }

            return button;
        }

        protected Gtk.ColorButton add_cbutton(Gtk.Box panel,
            bool tbox_inverse, string? tooltip = null) {
            var button = new Gtk.ColorButton();
            button.can_focus = false;
            button.add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            if (!Options.disable_tooltips) {
                button.set_tooltip_text(tooltip);
            }
            if (tbox_inverse) {
                panel.pack_end(button);
            } else {
                panel.pack_start(button);
            }

            return button;
        }

        protected Gtk.ScaleButton add_sbutton(Gtk.Box panel,
            bool tbox_inverse, string icon_fname, string? tooltip = null) {

            var button = new Gtk.ScaleButton(Gtk.IconSize.DIALOG,
                0, 50, 2, null);

            var bimage = load_icon(icon_fname, icon_height);
            bimage.show();
            button.set_image(bimage);

            button.set_relief(Gtk.ReliefStyle.NORMAL);
            button.get_adjustment().set_page_increment(4);

            button.add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            if (!Options.disable_tooltips) {
                button.set_tooltip_text(tooltip);
            }

            if (tbox_inverse) {
                panel.pack_end(button);
            } else {
                panel.pack_start(button);
            }

            // ignore input events on the main window while the scale popup
            // is active
            var popup = button.get_popup();
            popup.show.connect(() => {
                this.controller.set_ignore_input_events(true);
            });
            popup.hide.connect(() => {
                this.controller.set_ignore_input_events(false);
            });

            return button;
        }

        public ToolBox(Window.Presenter presenter, int icon_height) {
            this.icon_height = icon_height;
            this.controller = presenter.controller;

            Gtk.Orientation orientation = Gtk.Orientation.HORIZONTAL;
            bool tbox_inverse = false;

            switch (Options.toolbox_direction) {
                case Options.ToolboxDirection.LtoR:
                    orientation = Gtk.Orientation.HORIZONTAL;
                    tbox_inverse = false;
                    break;
                case Options.ToolboxDirection.RtoL:
                    orientation = Gtk.Orientation.HORIZONTAL;
                    tbox_inverse = true;
                    break;
                case Options.ToolboxDirection.TtoB:
                    orientation = Gtk.Orientation.VERTICAL;
                    tbox_inverse = false;
                    break;
                case Options.ToolboxDirection.BtoT:
                    orientation = Gtk.Orientation.VERTICAL;
                    tbox_inverse = true;
                    break;
            }
            toolbox = new Gtk.Box(orientation, 0);
            toolbox.get_style_context().add_class("toolbox");
            toolbox.halign = Gtk.Align.START;
            toolbox.valign = Gtk.Align.START;

            /* Toolbox handle consisting of an image + eventbox */
            var himage = load_icon("move.svg", icon_height);
            himage.show();

            var heventbox = new Gtk.EventBox();
            heventbox.button_press_event.connect(on_button_press);
            heventbox.motion_notify_event.connect(on_move_pointer);
            heventbox.add(himage);
            heventbox.set_events(
                  Gdk.EventMask.BUTTON_PRESS_MASK |
                  Gdk.EventMask.BUTTON1_MOTION_MASK
            );
            if (tbox_inverse) {
                this.toolbox.pack_end(heventbox);
            } else {
                this.toolbox.pack_start(heventbox);
            }

            Gtk.Button tb;
            tb = add_button(this.toolbox, tbox_inverse, "settings.svg",
                "Toggle toolbox panel");

            /* Toolbox panel that contains the buttons */
            var button_panel = new Gtk.Box(orientation, 0);
            button_panel.set_spacing(0);
            button_panel.set_homogeneous(true);

            if (Options.toolbox_minimized) {
                button_panel.set_child_visible(false);
            }
            if (tbox_inverse) {
                this.toolbox.pack_end(button_panel);
            } else {
                this.toolbox.pack_start(button_panel);
            }

            tb.clicked.connect(() => {
                    var state = button_panel.get_child_visible();
                    button_panel.set_child_visible(!state);
                });

            tb = add_button(button_panel, tbox_inverse, "empty.svg",
                "Normal mode");
            tb.clicked.connect(() => {
                    this.controller.set_normal_mode();
                });
            tb = add_button(button_panel, tbox_inverse, "highlight.svg",
                "Pointer mode");
            tb.clicked.connect(() => {
                    this.controller.set_pointer_mode();
                });
            tb = add_button(button_panel, tbox_inverse, "pen.svg",
                "Pen mode");
            tb.clicked.connect(() => {
                    this.controller.set_pen_mode();
                });
            tb = add_button(button_panel, tbox_inverse, "eraser.svg",
                "Eraser mode");
            tb.clicked.connect(() => {
                    this.controller.set_eraser_mode();
                });
            tb = add_button(button_panel, tbox_inverse, "spotlight.svg",
                "Spotlight mode");
            tb.clicked.connect(() => {
                    this.controller.set_spotlight_mode();
                });
            tb = add_button(button_panel, tbox_inverse, "snow.svg",
                "Freeze presentation window");
            tb.clicked.connect(() => {
                    this.controller.toggle_freeze();
                });
            tb = add_button(button_panel, tbox_inverse, "blank.svg",
                "Black presentation window");
            tb.clicked.connect(() => {
                    this.controller.fade_to_black();
                });
            tb = add_button(button_panel, tbox_inverse, "hidden.svg",
                "Hide presentation window");
            tb.clicked.connect(() => {
                    this.controller.hide_presentation();
                });
            tb = add_button(button_panel, tbox_inverse, "pause.svg",
                "Pause/resume timer");
            tb.clicked.connect(() => {
                    this.controller.toggle_pause();
                });

            scale_button = add_sbutton(button_panel, tbox_inverse,
                "linewidth.svg", "Drawing tool size");
            scale_button.hide();
            scale_button.value_changed.connect((val) => {
                this.controller.set_pen_size(val);
            });

            color_button = add_cbutton(button_panel, tbox_inverse,
                "Pen color");
            color_button.hide();
            color_button.color_set.connect(() => {
                    var rgba = color_button.rgba;
                    this.controller.pen_drawing.pen.set_rgba(rgba);
                    this.controller.queue_pen_surface_draws();
                });

            int tbox_x, tbox_y;
            calculate_position(presenter.window_w, presenter.window_h,
                out tbox_x, out tbox_y);
            this.put(this.toolbox, tbox_x, tbox_y);
        }

        public void update() {
            if (Options.toolbox_shown) {
                this.show();
            } else {
                this.hide();
            }

            var controller = this.controller;

            var rgba = controller.pen_drawing.pen.get_rgba();
            color_button.set_rgba(rgba);
            if (controller.is_pen_active()) {
                color_button.show();
            } else {
                color_button.hide();
            }

            scale_button.set_value(controller.get_pen_size());
            if (controller.is_pen_active() || controller.is_eraser_active()) {
                scale_button.show();
            } else {
                scale_button.hide();
            }
        }

        protected void calculate_position(int w, int h, out int x, out int y) {
            double fx = 0.0, fy = 0.0;
            double offset = 0.02*h;

            switch (Options.toolbox_direction) {
                case Options.ToolboxDirection.LtoR:
                    fx = 0.15*w + offset;
                    fy = 0.70*h + offset;
                    break;
                case Options.ToolboxDirection.RtoL:
                    fx = 0.15*w - offset;
                    fy = 0.70*h + offset;
                    break;
                case Options.ToolboxDirection.TtoB:
                    fx = 0*w + offset;
                    fy = 0*h + offset;
                    break;
                case Options.ToolboxDirection.BtoT:
                    fx = 0*w + offset;
                    fy = 0*h + offset;
                    break;
            }

            x = (int) fx;
            y = (int) fy;
        }

        public void on_window_resize(int w, int h) {
            int x, y;
            calculate_position(w, h, out x, out y);

            this.move(this.toolbox, x, y);
        }
    }
}
