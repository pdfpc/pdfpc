/**
 * Presentater window
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2012, 2015, 2017 Andreas Bilke
 * Copyright 2013 Gabor Adam Toth
 * Copyright 2015-2016 Andy Barry
 * Copyright 2015 Jeremy Maitin-Shepard
 * Copyright 2017 Olivier Pantalé
 * Copyright 2017 Evgeny Stambulchik
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

namespace pdfpc.Window {
    /**
     * Window showing the currently active and next slide.
     *
     * Other useful information like time slide count, ... can be displayed here as
     * well.
     */
    public class Presenter : Fullscreen, Controllable {
        /**
         * Only handle links and annotations on the current_view
         */
        public View.Pdf main_view {
            get {
                return this.current_view;
            }
        }

        /**
         * View showing the current slide
         */
        public View.Pdf current_view;

        /**
         * View showing a preview of the next slide
         */
        protected View.Pdf next_view;

        /**
         * Small views for (non-user) next slides
         */
        protected View.Pdf strict_next_view;
        protected View.Pdf strict_prev_view;

        /**
         * Timer for the presenation
         */
        protected TimerLabel? timer;

        /**
         * Slide progress label ( eg. "23/42" )
         */
        protected Gtk.Entry slide_progress;

        /**
         * The bottom row is 10% of the window height, fixed
         */
        private int bottom_frac_inv = 10;

        /**
         * Container for the status icons
         */
        protected Gtk.Box status;

        /**
         * Indication that the slide is blanked (faded to black)
         */
        protected Gtk.Image blank_icon;

        /**
         * Indication that the presentation window is hidden
         */
        protected Gtk.Image hidden_icon;

        /**
         * Indication that the presentation display is frozen
         */
        protected Gtk.Image frozen_icon;

        /**
         * Indication that the timer is paused
         */
        protected Gtk.Image pause_icon;

        /**
         * Indication that the slide is saved
         */
        protected Gtk.Image saved_icon;

        /**
         * Indication that the slide position has been loaded
         */
        protected Gtk.Image loaded_icon;

        /**
         * Indication that the notes are read-only (coming from PDF annotations)
         */
        protected Gtk.Image locked_icon;

        /**
         * Text box for displaying notes for the slides
         */
        protected Gtk.TextView notes_view;

        /**
         * CSS provider for setting note font size
         */
        protected Gtk.CssProvider css_provider;

        /**
         * CSS provider for setting timer and slide progress font size
         */
        protected Gtk.CssProvider bottom_text_css_provider;

        /**
         * Indication that the highlight tool is selected
         */
        protected Gtk.Image highlight_icon;

        /**
         * Indication that the pen tool is selected
         */
        protected Gtk.Image pen_icon;

        /**
         * Indication that the eraser tool is selected
         */
        protected Gtk.Image eraser_icon;

        /**
         * The overview of slides
         */
        protected Overview overview = null;

        /**
         * The Stack containing the slides view and the overview.
         */
        protected Gtk.Stack slide_stack;

        /**
         * Fixed layout - container of the toolbox.
         */
        protected Gtk.Fixed toolbox_container;

        /**
         * The toolbox with action buttons
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
        private int toolbox_x0;
        private int toolbox_y0;

        /**
         * Size of the toolbox button icons
         **/
        private int toolbox_icon_height;

        protected bool on_button_press(Gtk.Widget pbut, Gdk.EventButton event) {
            if (event.button == 1 ) {
                var w = this.get_window();

                w.get_position(out this.toolbox_x0, out this.toolbox_y0);

                this.toolbox_x0 += (int) event.x;
                this.toolbox_y0 += (int) event.y;
            }

            return true;
        }

        protected bool on_move_pointer(Gtk.Widget pbut, Gdk.EventMotion event) {
            int x = (int) event.x_root - this.toolbox_x0;
            int y = (int) event.y_root - this.toolbox_y0;

            if (true) {
                int dest_x, dest_y;
                toolbox.translate_coordinates(pbut, x, y,
                    out dest_x, out dest_y);
                this.toolbox_container.move(toolbox, dest_x, dest_y);
            }

            return true;
        }

        protected Gtk.Button add_toolbox_button(Gtk.Box panel,
            bool tbox_inverse, string icon_fname) {
            var bimage = this.load_icon(icon_fname, toolbox_icon_height);
            bimage.show();
            var button = new Gtk.Button();
            button.add(bimage);
            if (tbox_inverse) {
                panel.pack_end(button);
            } else {
                panel.pack_start(button);
            }

            return button;
        }

        protected Gtk.ColorButton add_toolbox_cbutton(Gtk.Box panel,
            bool tbox_inverse) {
            var button = new Gtk.ColorButton();
            if (tbox_inverse) {
                panel.pack_end(button);
            } else {
                panel.pack_start(button);
            }

            return button;
        }

        protected Gtk.ScaleButton add_toolbox_sbutton(Gtk.Box panel,
            bool tbox_inverse, string icon_fname) {

            var button = new Gtk.ScaleButton(Gtk.IconSize.DIALOG,
                0, 50, 2, null);

            var bimage = this.load_icon(icon_fname, toolbox_icon_height);
            bimage.show();
            button.set_image(bimage);

            button.set_relief(Gtk.ReliefStyle.NORMAL);
            button.get_adjustment().set_page_increment(4);

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

        protected Gtk.ScrolledWindow create_help_window() {
            var help_sw = new Gtk.ScrolledWindow(null, null);
            help_sw.set_policy(Gtk.PolicyType.AUTOMATIC,
                Gtk.PolicyType.AUTOMATIC);
            help_sw.get_style_context().add_class("help");
            help_sw.key_press_event.connect((event) => {
                    // Exit the help window on some reasonable keystrokes
                    switch (event.keyval) {
                    case Gdk.Key.Escape:
                    case Gdk.Key.Return:
                    case Gdk.Key.q:
                        this.show_help_window(false);
                        return true;
                    default:
                        return false;
                    }
                });

            var help_grid = new Gtk.Grid();
            help_grid.row_homogeneous = true;
            help_grid.column_spacing = 20;
            help_grid.margin = 20;
            help_sw.add(help_grid);

            var actions = this.controller.get_action_bindings();
            for (int i = 0; i < actions.length; i += 2) {
                int row = i/2;
                var action_lbl = new Gtk.Label(actions[i]);
                action_lbl.halign = Gtk.Align.START;
                var binding_lbl = new Gtk.Label(actions[i + 1]);
                binding_lbl.halign = Gtk.Align.START;
                help_grid.attach(action_lbl, 0, row);
                help_grid.attach(binding_lbl, 1, row);
            }

            return help_sw;
        }

        private void disable_paned_handle(Gtk.Paned paned) {
            paned.map.connect(() => {
                    var handle = paned.get_handle_window();
                    if (handle != null) {
                        handle.set_cursor(null);
                        handle.set_events(0);
                    }
                });
        }

        /**
         * (Re)load icons
         **/
        private void load_icons() {
            double bottom_height = (double) this.window_h/this.bottom_frac_inv;
            int icon_height = (int) (0.9*bottom_height);

            // Remove all existing icons
            var icons = this.status.get_children();
            foreach (Gtk.Widget icon in icons) {
                // NB: destroy() calls remove() internally!
                icon.destroy();
            }

            this.blank_icon = this.load_icon("blank.svg", icon_height);
            this.hidden_icon = this.load_icon("hidden.svg", icon_height);
            this.frozen_icon = this.load_icon("snow.svg", icon_height);
            this.pause_icon = this.load_icon("pause.svg", icon_height);
            this.saved_icon = this.load_icon("saved.svg", icon_height);
            this.loaded_icon = this.load_icon("loaded.svg", icon_height);
            this.locked_icon = this.load_icon("locked.svg", icon_height);

            this.highlight_icon = this.load_icon("highlight.svg", icon_height);
            this.pen_icon = this.load_icon("pen.svg", icon_height);
            this.eraser_icon = this.load_icon("eraser.svg", icon_height);

            this.status.pack_start(this.blank_icon, false, false);
            this.status.pack_start(this.hidden_icon, false, false);
            this.status.pack_start(this.frozen_icon, false, false);
            this.status.pack_start(this.pause_icon, false, false);
            this.status.pack_start(this.saved_icon, false, false);
            this.status.pack_start(this.loaded_icon, false, false);
            this.status.pack_start(this.locked_icon, false, false);
            this.status.pack_start(this.highlight_icon, false, false);
            this.status.pack_start(this.pen_icon, false, false);
            this.status.pack_start(this.eraser_icon, false, false);
        }

        /**
         * Update (hide/show) status icons
         **/
        private void update_status_icons() {
            if (this.timer.is_paused()) {
                this.pause_icon.show();
            } else {
                this.pause_icon.hide();
            }
            if (this.controller.faded_to_black) {
                this.blank_icon.show();
            } else {
                this.blank_icon.hide();
            }
            if (this.controller.hidden) {
                this.hidden_icon.show();
            } else {
                this.hidden_icon.hide();
            }
            if (this.controller.frozen) {
                this.frozen_icon.show();
            } else {
                this.frozen_icon.hide();
            }
            if (this.controller.is_pointer_active()) {
                this.highlight_icon.show();
            } else {
                this.highlight_icon.hide();
            }
            if (this.controller.is_eraser_active()) {
                this.eraser_icon.show();
            } else {
                this.eraser_icon.hide();
            }
            if (this.controller.is_pen_active()) {
                this.pen_icon.show();
            } else {
                this.pen_icon.hide();
            }
        }

        /**
         * Set font size for the timer & slide progress widgets
         **/
        private void resize_bottom_texts() {
            const string css_template = ".bottomText { font-size: %dpx; }";
            var target_size_height = (int) (12.0*this.window_h/400.0);
            var bottom_css = css_template.printf(target_size_height);

            try {
                this.bottom_text_css_provider.load_from_data(bottom_css, -1);
            } catch (Error e) {
                GLib.printerr("Warning: failed to set CSS for controls.\n");
            }
        }

        /**
         * Resize the overview
         **/
        private void resize_overview() {
            this.overview.set_available_space(this.window_w,
                (int) Math.floor(this.window_h*(1.0 - 1.0/bottom_frac_inv)));
        }

        /**
         * Resize parts of the GUI that cannot do it themselves (icons, text)
         **/
        protected override void resize_gui() {
            this.load_icons();
            this.update_status_icons();

            this.resize_bottom_texts();

            this.resize_overview();
        }

       /**
         * Base constructor instantiating a new presenter window
         */
        public Presenter(PresentationController controller,
            int screen_num, bool windowed) {
            base(controller, true, screen_num, windowed);

            this.controller.reload_request.connect(this.on_reload);
            this.controller.update_request.connect(this.update);
            this.controller.edit_note_request.connect(this.edit_note);
            this.controller.ask_goto_page_request.connect(this.ask_goto_page);
            this.controller.show_overview_request.connect(this.show_overview);
            this.controller.hide_overview_request.connect(this.hide_overview);
            this.controller.increase_font_size_request.connect(this.increase_font_size);
            this.controller.decrease_font_size_request.connect(this.decrease_font_size);

            // TODO: update the page aspect ratio on document reload
            float page_ratio = (float)
                (metadata.get_page_width()/metadata.get_page_height());

            // In most scenarios the current slide is displayed bigger than the
            // next one. The option current_size represents the width this view
            // should use as a percentage value. The maximal height is 90% of
            // the screen, as we need a place to display the timer and slide
            // count.
            int current_allocated_width = (int) Math.floor(
                this.window_w*Options.current_size/100.0);
            this.current_view = new View.Pdf.from_fullscreen(this,
                Metadata.Area.NOTES, true);

            this.next_view = new View.Pdf.from_fullscreen(this,
                Metadata.Area.CONTENT, false, true);

            this.strict_next_view = new View.Pdf.from_fullscreen(this,
                Metadata.Area.CONTENT, false);
            this.strict_prev_view = new View.Pdf.from_fullscreen(this,
                Metadata.Area.CONTENT, false);

            this.css_provider = new Gtk.CssProvider();
            Gtk.StyleContext.add_provider_for_screen(this.screen_to_use,
                css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

            // TextView for notes in the slides
            this.notes_view = new Gtk.TextView();
            this.notes_view.name = "notesView";
            this.notes_view.editable = false;
            this.notes_view.cursor_visible = false;
            this.notes_view.wrap_mode = Gtk.WrapMode.WORD;
            this.notes_view.buffer.text = "";
            this.notes_view.key_press_event.connect(this.on_key_press_notes_view);
            if (this.metadata.font_size >= 0) {
                // LEGACY font size detection
                // Before, we had the font size in absolute (device) units.
                // These were typically larger than 1000
                if (this.metadata.font_size >= 1000) {
                    this.metadata.font_size /= Pango.SCALE;
                }
                this.set_font_size(this.metadata.font_size);
            }

            this.bottom_text_css_provider = new Gtk.CssProvider();
            Gtk.StyleContext.add_provider_for_screen(this.screen_to_use,
                this.bottom_text_css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);

            // The countdown timer is centered in the 90% bottom part of the screen
            this.timer = this.controller.getTimer();
            this.timer.name = "timer";
            this.timer.get_style_context().add_class("bottomText");
            this.timer.set_justify(Gtk.Justification.CENTER);


            // The slide counter is centered in the 90% bottom part of the screen
            this.slide_progress = new Gtk.Entry();
            this.slide_progress.name = "slideProgress";
            this.slide_progress.get_style_context().add_class("bottomText");
            this.slide_progress.set_alignment(1f);
            this.slide_progress.sensitive = false;
            this.slide_progress.has_frame = false;
            this.slide_progress.key_press_event.connect(this.on_key_press_slide_progress);
            this.slide_progress.valign = Gtk.Align.END;
            // reduce the width of Gtk.Entry. we reserve a width for
            // 7 chars (i.e. maximal 999/999 for displaying)
            this.slide_progress.width_chars = 7;

            this.status = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            this.load_icons();

            this.add_events(Gdk.EventMask.KEY_PRESS_MASK);
            this.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            this.add_events(Gdk.EventMask.SCROLL_MASK);

            this.resize_bottom_texts();

            this.overview = new Overview(this.controller);
            this.overview.vexpand = true;
            this.overview.hexpand = true;
            this.overview.set_n_slides(this.controller.user_n_slides);
            this.controller.set_overview(this.overview);

            Gtk.AspectFrame frame;

            var slide_views = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
            slide_views.position = current_allocated_width;
            slide_views.wide_handle = true;
            disable_paned_handle(slide_views);

            var strict_views = new Gtk.Grid();
            strict_views.column_homogeneous = true;
            strict_views.row_homogeneous = true;
            strict_views.column_spacing = 10;
            frame = new Gtk.AspectFrame(null, 0.0f, 0.0f, page_ratio, false);
            frame.add(this.strict_prev_view);
            strict_views.attach(frame, 0, 0);
            frame = new Gtk.AspectFrame(null, 1.0f, 0.0f, page_ratio, false);
            frame.add(this.strict_next_view);
            strict_views.attach(frame, 1, 0);

            this.overlay_layout.add(this.current_view);

            this.video_surface.set_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.POINTER_MOTION_MASK);


            var current_view_and_stricts = new Gtk.Paned(Gtk.Orientation.VERTICAL);

            // Height of the window minus the bottom part (icons, timer, etc)
            var usable_height = (1.0 - 1.0/this.bottom_frac_inv)*this.window_h;

            double wheight1, wheight2;
            wheight1 = Options.current_height/100.0*usable_height;
            wheight2 = current_allocated_width/page_ratio;
            current_view_and_stricts.position = (int) double.min(wheight1, wheight2);

            current_view_and_stricts.wide_handle = true;
            disable_paned_handle(current_view_and_stricts);

            frame = new Gtk.AspectFrame(null, 0.5f, 0.0f, page_ratio, false);
            frame.add(overlay_layout);
            current_view_and_stricts.pack1(frame, true, true);
            current_view_and_stricts.pack2(strict_views, true, true);

            slide_views.pack1(current_view_and_stricts, true, true);

            var next_view_and_notes = new Gtk.Paned(Gtk.Orientation.VERTICAL);

            // To be exact, the width of Paned handle should be subtracted...
            var next_allocated_width = this.window_w - current_allocated_width;

            wheight1 = Options.next_height/100.0*usable_height;
            wheight2 = next_allocated_width/page_ratio;
            next_view_and_notes.position = (int) double.min(wheight1, wheight2);

            next_view_and_notes.wide_handle = true;
            disable_paned_handle(next_view_and_notes);

            frame = new Gtk.AspectFrame(null, 0.5f, 0.0f, page_ratio, false);
            frame.add(next_view);
            next_view_and_notes.pack1(frame, true, true);

            var notes_sw = new Gtk.ScrolledWindow(null, null);
            notes_sw.add(this.notes_view);
            notes_sw.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            next_view_and_notes.pack2(notes_sw, true, true);
            slide_views.pack2(next_view_and_notes, true, true);

            var help_sw = create_help_window();

            this.slide_stack = new Gtk.Stack();
            this.slide_stack.add_named(slide_views, "slides");
            this.slide_stack.add_named(this.overview, "overview");
            this.slide_stack.add_named(help_sw, "help");
            this.slide_stack.homogeneous = true;

            var bottom_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            bottom_row.homogeneous = true;

            this.timer.halign = Gtk.Align.CENTER;
            this.timer.valign = Gtk.Align.END;

            bottom_row.pack_start(this.status);
            bottom_row.pack_start(this.timer);
            bottom_row.pack_end(this.slide_progress, false);

            Gtk.Grid full_layout = new Gtk.Grid();
            full_layout.row_homogeneous = true;
            full_layout.attach(this.slide_stack, 0, 0, 1, this.bottom_frac_inv - 1);
            full_layout.attach(bottom_row, 0, this.bottom_frac_inv - 1, 1, 1);

            Gtk.Overlay full_overlay = new Gtk.Overlay();
            full_overlay.add_overlay(full_layout);

            // maybe should be calculated based on screen dimensions?
            this.toolbox_icon_height = 36;

            Gtk.Orientation toolbox_orientation = Gtk.Orientation.HORIZONTAL;
            bool tbox_inverse = false;
            int tb_offset = (int) (0.02*this.window_h);

            int tbox_x = 0, tbox_y = 0;
            switch (Options.toolbox_direction) {
                case Options.ToolboxDirection.LtoR:
                    toolbox_orientation = Gtk.Orientation.HORIZONTAL;
                    tbox_inverse = false;
                    tbox_x = (int) (0.15*this.window_w) + tb_offset;
                    tbox_y = (int) (0.70*this.window_h) + tb_offset;
                    break;
                case Options.ToolboxDirection.RtoL:
                    toolbox_orientation = Gtk.Orientation.HORIZONTAL;
                    tbox_inverse = true;
                    tbox_x = (int) (0.15*this.window_w) - tb_offset;
                    tbox_y = (int) (0.70*this.window_h) + tb_offset;
                    break;
                case Options.ToolboxDirection.TtoB:
                    toolbox_orientation = Gtk.Orientation.VERTICAL;
                    tbox_inverse = false;
                    tbox_x = 0*this.window_w + tb_offset;
                    tbox_y = 0*this.window_h + tb_offset;
                    break;
                case Options.ToolboxDirection.BtoT:
                    toolbox_orientation = Gtk.Orientation.VERTICAL;
                    tbox_inverse = true;
                    tbox_x = 0*this.window_w + tb_offset;
                    tbox_y = 0*this.window_h + tb_offset;
                    break;
            }
            toolbox = new Gtk.Box(toolbox_orientation, 0);
            toolbox.get_style_context().add_class("toolbox");
            toolbox.halign = Gtk.Align.START;
            toolbox.valign = Gtk.Align.START;

            toolbox.set_child_visible(Options.toolbox_shown);

            /* Toolbox handle consisting of an image + eventbox */
            var himage = this.load_icon("move.svg", 30);
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
            tb = add_toolbox_button(this.toolbox, tbox_inverse, "settings.svg");

            /* Toolbox panel that contains the buttons */
            var button_panel = new Gtk.Box(toolbox_orientation, 0);
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

            tb = add_toolbox_button(button_panel, tbox_inverse, "empty.svg");
            tb.clicked.connect(() => {
                    this.controller.set_normal_mode();
                });
            tb = add_toolbox_button(button_panel, tbox_inverse, "highlight.svg");
            tb.clicked.connect(() => {
                    this.controller.set_pointer_mode();
                });
            tb = add_toolbox_button(button_panel, tbox_inverse, "pen.svg");
            tb.clicked.connect(() => {
                    this.controller.set_pen_mode();
                });
            tb = add_toolbox_button(button_panel, tbox_inverse, "eraser.svg");
            tb.clicked.connect(() => {
                    this.controller.set_eraser_mode();
                });
            tb = add_toolbox_button(button_panel, tbox_inverse, "snow.svg");
            tb.clicked.connect(() => {
                    this.controller.toggle_freeze();
                });
            tb = add_toolbox_button(button_panel, tbox_inverse, "blank.svg");
            tb.clicked.connect(() => {
                    this.controller.fade_to_black();
                });
            tb = add_toolbox_button(button_panel, tbox_inverse, "hidden.svg");
            tb.clicked.connect(() => {
                    this.controller.hide_presentation();
                });
            tb = add_toolbox_button(button_panel, tbox_inverse, "pause.svg");
            tb.clicked.connect(() => {
                    this.controller.toggle_pause();
                });

            scale_button = add_toolbox_sbutton(button_panel, tbox_inverse,
                "linewidth.svg");
            scale_button.set_child_visible(false);
            scale_button.value_changed.connect((val) => {
                this.controller.set_pen_size(val);
            });

            color_button = add_toolbox_cbutton(button_panel, tbox_inverse);
            color_button.set_child_visible(false);
            color_button.color_set.connect(() => {
                    var rgba = color_button.rgba;
                    this.controller.pen_drawing.pen.set_rgba(rgba);
                    this.controller.queue_pen_surface_draws();
                });

            this.toolbox_container = new Gtk.Fixed();
            this.toolbox_container.put(toolbox, tbox_x, tbox_y);

            full_overlay.add_overlay(this.toolbox_container);
            full_overlay.set_overlay_pass_through(this.toolbox_container, true);

            this.add(full_overlay);
        }

        public override void show() {
            base.show();
            this.resize_overview();
        }

       /**
         * Load an (SVG) icon, replacing a substring in it in special cases
         */
        protected Gtk.Image load_icon(string filename, int icon_height) {
            // attempt to load from a local path (if the user hasn't installed)
            // if that fails, attempt to load from the global path
            string load_icon_path;
            if (Options.no_install) {
                load_icon_path = Path.build_filename(Paths.SOURCE_PATH, "icons",
                    filename);
            } else {
                load_icon_path = Path.build_filename(Paths.ICON_PATH, filename);
            }
            File icon_file = File.new_for_path(load_icon_path);

            Gtk.Image icon;
            try {
                int width = icon_height;
                int height = icon_height;

                if (!Pdfpc.is_Wayland_backend()) {
                    width *= this.gdk_scale;
                    height *= this.gdk_scale;
                }

                Gdk.Pixbuf pixbuf;
                if (filename == "highlight.svg") {
                    uint8[] contents;
                    string etag_out;
                    icon_file.load_contents(null, out contents, out etag_out);

                    string buf = (string) contents;
                    buf = buf.replace("pointer_color", Options.pointer_color);

                    MemoryInputStream stream =
                        new MemoryInputStream.from_data(buf.data);

                    pixbuf = new Gdk.Pixbuf.from_stream_at_scale(stream,
                        width, height, true);
                } else {
                    pixbuf = new Gdk.Pixbuf.from_file_at_scale(load_icon_path,
                        width, height, true);
                }

                Cairo.Surface surface =
                    Gdk.cairo_surface_create_from_pixbuf(pixbuf, 0, null);

                icon = new Gtk.Image.from_surface(surface);
                icon.no_show_all = true;
            } catch (Error e) {
                GLib.printerr("Warning: Could not load icon %s (%s)\n",
                    load_icon_path, e.message);
                icon = new Gtk.Image.from_icon_name("image-missing",
                    Gtk.IconSize.LARGE_TOOLBAR);
            }
            return icon;
        }

        public void session_saved() {
            this.saved_icon.show();
        }

        public void session_loaded() {
            this.loaded_icon.show();
        }

        /**
         * Update the slide count view
         */
        protected void update_slide_count() {
            int current_user_slide_number =
                this.controller.current_user_slide_number;
            this.custom_slide_count(current_user_slide_number + 1);
        }

        public void custom_slide_count(int current) {
            int total = this.metadata.get_end_user_slide();
            this.slide_progress.set_text("%d/%u".printf(current, total));
        }

        protected void update_toolbox() {
            toolbox.set_child_visible(Options.toolbox_shown);

            var controller = this.controller;

            var rgba = controller.pen_drawing.pen.get_rgba();
            color_button.set_rgba(rgba);
            color_button.set_child_visible(controller.is_pen_active());

            scale_button.set_value(controller.get_pen_size());
            scale_button.set_child_visible(controller.is_pen_active() ||
                controller.is_eraser_active());
        }

        /**
         * Called on document reload.
         * TODO: in principle the document geometry may change!
         */
        public void on_reload() {
            this.current_view.invalidate();
            this.next_view.invalidate();
            this.strict_next_view.invalidate();
            this.strict_prev_view.invalidate();
        }

        public void update() {
            if (!metadata.is_ready) {
                return;
            }
            int current_slide_number = this.controller.current_slide_number;
            int current_user_slide_number = this.controller.current_user_slide_number;

            this.current_view.display(current_slide_number);
            int next_view_slide_offset = 0;
            if (   !Options.final_slide_overlay
                || (Options.final_slide_overlay && current_slide_number == this.metadata.user_slide_to_real_slide(current_user_slide_number))
               ){
                next_view_slide_offset = 1;
            }
            this.next_view.display(
                this.metadata.user_slide_to_real_slide(current_user_slide_number + next_view_slide_offset)
            );
            if (this.controller.skip_next()) {
                this.strict_next_view.disabled = false;
            } else {
                this.strict_next_view.disabled = true;
            }
            this.strict_next_view.display(current_slide_number + 1);
            if (this.controller.skip_previous()) {
                this.strict_prev_view.disabled = false;
            } else {
                this.strict_prev_view.disabled = true;
            }
            this.strict_prev_view.display(current_slide_number - 1);

            this.update_slide_count();
            this.update_note();

            this.update_status_icons();

            if (this.controller.hidden) {
                // Ensure the presenter window remains focused
                this.present();
            }

            this.saved_icon.hide();
            this.loaded_icon.hide();
            this.locked_icon.hide();

            this.update_toolbox();
        }

        /**
         * Ask for the page to jump to
         */
        public void ask_goto_page() {
            // Ignore events coming from the presentation view
            if (!this.is_active) {
                return;
            }

            this.slide_progress.set_text("/%u".printf(this.controller.user_n_slides));
            this.slide_progress.sensitive = true;
            this.slide_progress.grab_focus();
            this.slide_progress.set_position(0);
            this.controller.set_ignore_input_events(true);
        }

        /**
         * Handle key events for the slide_progress entry field
         */
        protected bool on_key_press_slide_progress(Gtk.Widget source, Gdk.EventKey key) {
            if (key.keyval == Gdk.Key.Return) {
                // Try to parse the input
                string input_text = this.slide_progress.text;
                int destination = int.parse(input_text.substring(0, input_text.index_of("/")));
                this.slide_progress.sensitive = false;
                this.controller.set_ignore_input_events(false);
                if (destination != 0)
                    this.controller.goto_user_page(destination - 1);
                else
                    this.update_slide_count(); // Reset the display we had before
                return true;
            } else if (key.keyval == Gdk.Key.Escape) {
                this.slide_progress.sensitive = false;
                this.controller.set_ignore_input_events(false);
                this.update_slide_count();
                return true;
            } else {
                return false;
            }
        }

        private void blink_lock_icon() {
            this.locked_icon.show();
            GLib.Timeout.add(1000, () => {
                    this.locked_icon.hide();
                    return false;
                });
        }

        /**
         * Edit a note. Basically give focus to notes_view
         */
        public void edit_note() {
            // Ignore events coming from the presentation view
            if (!this.is_active) {
                return;
            }

            // Disallow editing notes imported from PDF annotations
            int number = this.controller.current_user_slide_number;
            if (this.metadata.get_notes().is_note_read_only(number)) {
                blink_lock_icon();
                return;
            }

            this.notes_view.editable = true;
            this.notes_view.cursor_visible = true;
            this.notes_view.grab_focus();
            this.controller.set_ignore_input_events(true);
        }

        /**
         * Handle key presses when editing a note
         */
        protected bool on_key_press_notes_view(Gtk.Widget source, Gdk.EventKey key) {
            if (key.keyval == Gdk.Key.Escape) { /* Escape */
                this.notes_view.editable = false;
                this.notes_view.cursor_visible = false;
                this.metadata.get_notes().set_note(this.notes_view.buffer.text,
                    this.controller.current_user_slide_number);
                this.controller.set_ignore_input_events(false);
                return true;
            } else {
                return false;
            }
        }

        /**
         * Update the text of the current note
         */
        protected void update_note() {
            string this_note = this.metadata.get_notes().get_note_for_slide(
                this.controller.current_user_slide_number);
            this.notes_view.buffer.text = this_note;
        }

        public void show_overview() {
            // Ignore events coming from the presentation view
            if (!this.is_active) {
                return;
            }

            this.overview.current_slide = this.controller.current_user_slide_number;
            this.slide_stack.set_visible_child_name("overview");
            this.overview.ensure_focus();
        }

        public void hide_overview() {
            this.slide_stack.set_visible_child_name("slides");
        }

        public bool is_overview_shown() {
            return (this.slide_stack.get_visible_child() == this.overview);
        }

        /**
         * Increase font sizes for Widgets
         */
        public void increase_font_size() {
            int font_size = get_font_size();
            font_size += 2;
            this.metadata.font_size = font_size;
            set_font_size(font_size);
        }

        /**
         * Decrease font sizes for Widgets
         */
        public void decrease_font_size() {
            int font_size = get_font_size();
            font_size -= 2;
            if (font_size < 2) {
                font_size = 2;
            }
            this.metadata.font_size = font_size;
            set_font_size(font_size);
        }

        private int get_font_size() {
            Gtk.StyleContext style_context = this.notes_view.get_style_context();
            Pango.FontDescription font_desc;
            style_context.get(style_context.get_state(), "font", out font_desc, null);

            return font_desc.get_size()/Pango.SCALE;
        }

        private void set_font_size(int size) {
            const string text_css_template = "#notesView { font-size: %dpt; }";
            var css = text_css_template.printf(size);

            try {
                css_provider.load_from_data(css, -1);
            } catch (Error e) {
                GLib.printerr("Warning: failed to set CSS for notes.\n");
            }
        }

        public void show_help_window(bool onoff) {
            if (onoff) {
                this.slide_stack.set_visible_child_name("help");
                this.slide_stack.get_child_by_name("help").grab_focus();
                this.controller.set_ignore_input_events(true);
            } else {
                this.slide_stack.set_visible_child_name("slides");
                this.controller.set_ignore_input_events(false);
            }
        }
    }
}
