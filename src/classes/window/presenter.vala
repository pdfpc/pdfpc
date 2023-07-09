/**
 * Presenter window
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
     * An auxiliary function to load an icon (essentially, a square image)
     */
    public Gtk.Image load_icon(string filename, int size) {
        Gtk.Image icon;
        var surface = Renderer.Image.render(filename, size, size);
        if (surface != null) {
            icon = new Gtk.Image.from_surface(surface);
        } else {
            icon = new Gtk.Image.from_icon_name("image-missing",
                Gtk.IconSize.LARGE_TOOLBAR);
        }
        icon.no_show_all = true;
        return icon;
    }

    /**
     * Window showing the currently active and next slide.
     *
     * Other useful information like time slide count, ... can be displayed here as
     * well.
     */
    public class Presenter : ControllableWindow {
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
         * A stack of text box (for editing) and rendered view of notes
         * for the current slide
         */
        protected Gtk.Stack notes_stack;
        protected Gtk.TextView notes_editor;
        protected View.Pdf notes_view;
#if MDVIEW
        protected View.MarkdownView mdview;
#endif
        protected Gtk.Paned slide_views;
        protected Gtk.Paned current_view_and_stricts;
        protected Gtk.Paned next_view_and_notes;
        protected Gtk.Paned full_layout;

        /**
         * Timer for the presenation
         */
        protected Gtk.Label timer_label;

        /**
         * Slide progress label ( eg. "23/42" )
         */
        protected Gtk.Entry slide_progress;

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
         * Indication that the spotlight tool is selected
         */
        protected Gtk.Image spotlight_icon;

        /**
         * The overview of slides
         */
        protected Overview overview = null;

        /**
         * The Stack containing the slides view and the overview.
         */
        protected Gtk.Stack slide_stack;

        /**
         * The toolbox with action buttons
         */
        protected ToolBox toolbox;


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

        private void enable_paned_handle(Gtk.Paned paned, bool onoff) {
            var handle = paned.get_handle_window();
            if (handle != null) {
                Gdk.EventMask emask;
                Gdk.Cursor cursor;
                Gtk.StyleContext context = this.get_style_context();
                if (onoff) {
                    cursor = handle.get_data<Gdk.Cursor>("cursor");
                    emask  = handle.get_data<Gdk.EventMask>("emask");
                    context.add_class("customization");
                } else {
                    cursor = null;
                    emask = 0;
                    context.remove_class("customization");
                }
                handle.set_cursor(cursor);
                handle.set_events(emask);
            }
        }

        /**
         * A wrapper for the Gtk.Paned constructor providing the
         * enable/disable functionality which is missing in Gtk
         */
        protected Gtk.Paned create_paned(Gtk.Orientation orientation)
        {
            var paned = new Gtk.Paned(orientation);
            paned.wide_handle = true;
            paned.map.connect(() => {
                    var handle = paned.get_handle_window();
                    if (handle != null &&
                        !handle.get_data<bool>("initialized")) {
                        // save default cursor and event mask of the handle
                        handle.set_data<Gdk.Cursor>("cursor",
                            handle.get_cursor());
                        handle.set_data<Gdk.EventMask>("emask",
                            handle.get_events());
                        handle.set_data<bool>("initialized", true);

                        // start in the disabled state
                        this.enable_paned_handle(paned, false);
                    }
                });

            return paned;
        }

        public void set_customizable(bool onoff) {
            enable_paned_handle(this.slide_views, onoff);
            enable_paned_handle(this.current_view_and_stricts, onoff);
            enable_paned_handle(this.next_view_and_notes, onoff);
            enable_paned_handle(this.full_layout, onoff);
        }

        public bool current_view_maximized {
            get; protected set; default = false;
        }

        public void maximize_current_view(bool onoff) {
            if (this.current_view_maximized == onoff) {
                // nothing to do
                return;
            }

            int width, height;
            if (onoff) {
                width  = this.window_w;
                height = this.current_view_and_stricts.get_allocated_height();
                // save the current positions
                this.slide_views.set_data<int>("position",
                    this.slide_views.position);
                this.current_view_and_stricts.set_data<int>("position",
                    this.current_view_and_stricts.position);
            } else {
                // get the saved positions
                width  = this.slide_views.get_data<int>("position");
                height = this.current_view_and_stricts.get_data<int>("position");
            }

            this.slide_views.position = width;
            this.current_view_and_stricts.position = height;

            this.current_view_maximized = onoff;
        }

        public void show_status_icons(bool onoff) {
            if (onoff) {
                this.update_status_icons();
            } else {
                var icons = this.status.get_children();
                foreach (Gtk.Widget icon in icons) {
                    icon.hide();
                }
            }
        }

        /**
         * (Re)load status icons
         **/
        private void reload_status_icons(int height) {
            if (!Pdfpc.is_Wayland_backend() && !Pdfpc.is_Quartz_backend()) {
                height *= this.gdk_scale;
            }

            // Remove all existing icons
            var icons = this.status.get_children();
            foreach (Gtk.Widget icon in icons) {
                // NB: destroy() calls remove() internally!
                icon.destroy();
            }

            this.blank_icon = load_icon("blank.svg", height);
            this.hidden_icon = load_icon("hidden.svg", height);
            this.frozen_icon = load_icon("snow.svg", height);
            this.pause_icon = load_icon("pause.svg", height);
            this.saved_icon = load_icon("saved.svg", height);
            this.loaded_icon = load_icon("loaded.svg", height);
            this.locked_icon = load_icon("locked.svg", height);

            this.highlight_icon = load_icon("highlight.svg", height);
            this.pen_icon = load_icon("pen.svg", height);
            this.eraser_icon = load_icon("eraser.svg", height);
            this.spotlight_icon = load_icon("spotlight.svg", height);

            this.status.pack_start(this.blank_icon, false, true);
            this.status.pack_start(this.hidden_icon, false, true);
            this.status.pack_start(this.frozen_icon, false, true);
            this.status.pack_start(this.pause_icon, false, true);
            this.status.pack_start(this.saved_icon, false, true);
            this.status.pack_start(this.loaded_icon, false, true);
            this.status.pack_start(this.locked_icon, false, true);
            this.status.pack_start(this.highlight_icon, false, true);
            this.status.pack_start(this.pen_icon, false, true);
            this.status.pack_start(this.eraser_icon, false, true);
            this.status.pack_start(this.spotlight_icon, false, true);
        }

        /**
         * Update (hide/show) status icons
         **/
        private void update_status_icons() {
            if (this.controller.is_paused()) {
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
            if (this.controller.is_spotlight_active()) {
                this.spotlight_icon.show();
            } else {
                this.spotlight_icon.hide();
            }
        }

        /**
         * Set font size for the timer & slide progress widgets
         **/
        private void resize_bottom_texts(int height) {
            const string css_template = ".bottomText { font-size: %dpx; }";
            int font_size = (int) (0.7*height);
            var bottom_css = css_template.printf(font_size);

            try {
                this.bottom_text_css_provider.load_from_data(bottom_css, -1);
            } catch (Error e) {
                GLib.printerr("Warning: failed to set CSS for controls.\n");
            }
        }

        // Explicitly defined via CSS
        private int handle_thickness = 5;

        private int bottom_height = 0;

        private void on_bottom_resize(Gtk.Allocation a) {
            int height = a.height;

            // If any of the status icons is visible, there is a problem:
            // unfortunately, Gtk.Icon is not shrinkable, so we try to detect
            // an attempt to decrease the bottom pane height by checking
            // whether the total height exceeds the vertical dimension of the
            // window.
            int jutting = this.slide_stack.get_allocated_height() +
                height + handle_thickness - this.window_h;
            if (jutting > 0) {
                height -= jutting;
            }

            if (this.bottom_height != height) {
                this.bottom_height = height;

                this.reload_status_icons(height);
                this.update_status_icons();

                this.resize_bottom_texts(height);

                this.overview.set_available_space(this.window_w,
                    this.window_h - height);
            }
        }

        /**
         * Base constructor instantiating a new presenter window
         */
        public Presenter(PresentationController controller,
            int screen_num, bool windowed) {
            base(controller, true, screen_num, windowed);

            this.title = "pdfpc - presenter (%s)".
                printf(controller.metadata.get_title());

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
            // should use as a percentage value.
            int current_allocated_width = (int)
                (this.window_w*Options.current_size/100.0);

            this.next_view = new View.Pdf.from_controllable_window(this,
                false, false, true);

            this.strict_next_view = new View.Pdf.from_controllable_window(this,
                false, false);
            this.strict_prev_view = new View.Pdf.from_controllable_window(this,
                false, false);

            this.css_provider = new Gtk.CssProvider();
            Gtk.StyleContext.add_provider_for_screen(this.screen_to_use,
                this.css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

            this.bottom_text_css_provider = new Gtk.CssProvider();
            Gtk.StyleContext.add_provider_for_screen(this.screen_to_use,
                this.bottom_text_css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);

            Gtk.AspectFrame frame;

            // TextView for notes in the slides
            this.notes_editor = new Gtk.TextView();
            this.notes_editor.name = "notesView";
            this.notes_editor.editable = false;
            this.notes_editor.cursor_visible = false;
            this.notes_editor.wrap_mode = Gtk.WrapMode.WORD;
            this.notes_editor.buffer.text = "";
            this.notes_editor.key_press_event.connect(this.on_key_press_notes_editor);
            var notes_sw = new Gtk.ScrolledWindow(null, null);
            notes_sw.add(this.notes_editor);
            notes_sw.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);

            this.notes_view = new View.Pdf.from_controllable_window(this,
                true, false);
            frame = new Gtk.AspectFrame(null, 0.5f, 0.0f, page_ratio, false);
            frame.add(this.notes_view);

            // The full notes stack
            this.notes_stack = new Gtk.Stack();
            this.notes_stack.add_named(notes_sw, "editor");
            this.notes_stack.add_named(frame, "view");
#if MDVIEW
            // The Markdown rendering widget
            this.mdview = new View.MarkdownView();
            this.notes_stack.add_named(this.mdview, "mdview");
#endif
            this.notes_stack.homogeneous = true;

            var meta_font_size = this.metadata.get_font_size();
            this.apply_font_size(meta_font_size);

            // The countdown timer is centered in the bottom part of the screen
            this.timer_label = new Gtk.Label("");
            this.timer_label.name = "timer";
            this.timer_label.get_style_context().add_class("bottomText");
            this.timer_label.set_justify(Gtk.Justification.CENTER);
            this.timer_label.halign = Gtk.Align.CENTER;
            this.timer_label.valign = Gtk.Align.CENTER;
            this.timer_label.margin = 0;

            this.controller.timer_change.connect((str) => {
                    var context = this.get_style_context();

                    // Clear any previously assigned class
                    context.remove_class("pretalk");
                    context.remove_class("too-fast");
                    context.remove_class("too-slow");
                    context.remove_class("last-minutes");
                    context.remove_class("overtime");

                    switch (this.controller.progress_status) {
                    case PresentationController.ProgressStatus.PreTalk:
                        context.add_class("pretalk");
                        break;
                    case PresentationController.ProgressStatus.Fast:
                        context.add_class("too-fast");
                        break;
                    case PresentationController.ProgressStatus.Slow:
                        context.add_class("too-slow");
                        break;
                    case PresentationController.ProgressStatus.LastMinutes:
                        context.add_class("last-minutes");
                        break;
                    case PresentationController.ProgressStatus.Overtime:
                        context.add_class("overtime");
                        break;
                    default:
                        break;
                    }

                    this.timer_label.set_label(str);
                });
            this.controller.reset_timer();

            // The slide counter
            this.slide_progress = new Gtk.Entry();
            this.slide_progress.name = "slideProgress";
            this.slide_progress.get_style_context().add_class("bottomText");
            this.slide_progress.set_alignment(1f);
            this.slide_progress.sensitive = false;
            this.slide_progress.has_frame = false;
            this.slide_progress.key_press_event.connect(this.on_key_press_slide_progress);
            this.slide_progress.valign = Gtk.Align.CENTER;
            // Reduce the width of Gtk.Entry, reserving room for 7 characters
            // (i.e., up to 999/999).
            this.slide_progress.width_chars = 7;

            this.status = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

            this.overview = new Overview(this.controller);
            this.overview.vexpand = true;
            this.overview.hexpand = true;
            this.overview.set_n_slides(this.controller.user_n_slides);
            this.controller.overview = this.overview;

            this.slide_views = create_paned(Gtk.Orientation.HORIZONTAL);
            this.slide_views.position = current_allocated_width;

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

            this.current_view_and_stricts =
                create_paned(Gtk.Orientation.VERTICAL);

            // Height of the window minus the status area and the Paned handle
            var main_height = (1.0 - Options.status_height/100.0)*this.window_h;

            double wheight1, wheight2;
            wheight1 = Options.current_height/100.0*main_height;
            wheight2 = current_allocated_width/page_ratio;
            this.current_view_and_stricts.position =
                (int) double.min(wheight1, wheight2);

            frame = new Gtk.AspectFrame(null, 0.5f, 0.0f, page_ratio, false);
            frame.add(overlay_layout);
            this.current_view_and_stricts.pack1(frame, true, true);
            this.current_view_and_stricts.pack2(strict_views, true, true);

            this.slide_views.pack1(this.current_view_and_stricts, true, true);

            this.next_view_and_notes = create_paned(Gtk.Orientation.VERTICAL);

            var next_allocated_width = this.window_w - current_allocated_width
                - this.handle_thickness;

            wheight1 = Options.next_height/100.0*main_height;
            wheight2 = next_allocated_width/page_ratio;
            this.next_view_and_notes.position =
                (int) double.min(wheight1, wheight2);

            frame = new Gtk.AspectFrame(null, 0.5f, 0.0f, page_ratio, false);
            frame.add(next_view);
            this.next_view_and_notes.pack1(frame, true, true);

            this.next_view_and_notes.pack2(this.notes_stack, true, true);
            this.slide_views.pack2(this.next_view_and_notes, true, true);

            var help_sw = create_help_window();
#if REST
            var qrcode_da = new QRCode(this.controller, 0.5*this.window_h);
            qrcode_da.key_press_event.connect((event) => {
                    // Close this window on some reasonable keystrokes
                    switch (event.keyval) {
                    case Gdk.Key.Escape:
                    case Gdk.Key.Return:
                    case Gdk.Key.q:
                        this.show_qrcode_window(false);
                        return true;
                    default:
                        return false;
                    }
                });
#endif
            this.slide_stack = new Gtk.Stack();
            this.slide_stack.add_named(this.slide_views, "slides");
            this.slide_stack.add_named(this.overview, "overview");
            this.slide_stack.add_named(help_sw, "help");
#if REST
            this.slide_stack.add_named(qrcode_da, "qrcode");
#endif
            this.slide_stack.homogeneous = true;

            var bottom_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            bottom_row.homogeneous = true;

            bottom_row.pack_start(this.status);
            bottom_row.pack_start(this.timer_label);
            bottom_row.pack_start(this.slide_progress);
            bottom_row.size_allocate.connect(this.on_bottom_resize);

            this.full_layout = create_paned(Gtk.Orientation.VERTICAL);
            this.full_layout.position = (int) main_height;
            this.full_layout.pack1(this.slide_stack, true, true);
            this.full_layout.pack2(bottom_row, true, true);

            var full_overlay = new Gtk.Overlay();
            full_overlay.add(this.full_layout);

            // maybe should be calculated based on screen dimensions?
            int toolbox_icon_height = 36;
            if (!Pdfpc.is_Wayland_backend() && !Pdfpc.is_Quartz_backend()) {
                toolbox_icon_height *= this.gdk_scale;
            }
            this.toolbox = new Window.ToolBox(this, toolbox_icon_height);

            full_overlay.add_overlay(this.toolbox);
            full_overlay.set_overlay_pass_through(this.toolbox, true);

            this.add_top_container(full_overlay);
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
            int total = this.metadata.get_end_user_slide() + 1;
            this.slide_progress.set_text("%d/%u".printf(current, total));
        }


        /**
         * Called on document reload.
         * TODO: in principle the document geometry may change!
         */
        public void on_reload() {
            this.next_view.invalidate();
            this.strict_next_view.invalidate();
            this.strict_prev_view.invalidate();
            this.notes_view.invalidate();
            this.overview.set_n_slides(this.controller.user_n_slides);
        }

        public void update() {
            if (!this.metadata.is_ready) {
                return;
            }

            int current_slide_number = this.controller.current_slide_number;
            int current_user_slide_number =
                this.controller.current_user_slide_number;

            this.main_view.display(current_slide_number);

            var next_view_user_slide = current_user_slide_number;
            bool show_final_slide_of_current_overlay =
                Options.final_slide_overlay &&
                !this.metadata.is_user_slide(current_slide_number);
            if (!show_final_slide_of_current_overlay) {
                next_view_user_slide++;
            }

            var view_slide_number =
                this.metadata.user_slide_to_real_slide(next_view_user_slide,
                show_final_slide_of_current_overlay ||
                !Options.next_slide_first_overlay);
            view_slide_number = metadata.nearest_nonhidden(view_slide_number);
            this.next_view.disabled = (view_slide_number < 0);
            this.next_view.display(view_slide_number);

            view_slide_number =
                this.metadata.next_in_overlay(current_slide_number);
            view_slide_number = metadata.nearest_nonhidden(view_slide_number);
            this.strict_next_view.disabled = (view_slide_number < 0);
            this.strict_next_view.display(view_slide_number);

            view_slide_number =
                this.metadata.prev_in_overlay(current_slide_number);
            view_slide_number = metadata.nearest_nonhidden(view_slide_number,
                true);
            this.strict_prev_view.disabled = (view_slide_number < 0);
            this.strict_prev_view.display(view_slide_number);

            if (this.metadata.has_beamer_notes) {
                this.notes_stack.set_visible_child_name("view");
                this.notes_view.display(current_slide_number);
            } else {
#if MDVIEW
                this.notes_stack.set_visible_child_name("mdview");
#endif
                this.update_note();
            }

            this.update_slide_count();

            this.update_status_icons();

            if (this.controller.hidden) {
                // Ensure the presenter window remains focused
                this.present();
            }

            this.saved_icon.hide();
            this.loaded_icon.hide();
            this.locked_icon.hide();

            this.toolbox.update();
        }

        protected override void resize_gui() {
            this.toolbox.on_window_resize(this.window_w, this.window_h);
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
         * Edit a note. Basically give focus to notes_editor
         */
        public void edit_note() {
            // Ignore events coming from the presentation view
            if (!this.is_active) {
                return;
            }

            // Disallow editing notes imported from PDF annotations
            int number = this.controller.current_user_slide_number;
            if (this.metadata.is_note_read_only(number) ||
                this.metadata.has_beamer_notes) {
                blink_lock_icon();
                return;
            }

            this.notes_stack.set_visible_child_name("editor");
            this.notes_editor.editable = true;
            this.notes_editor.cursor_visible = true;
            this.notes_editor.grab_focus();
            this.controller.set_ignore_input_events(true);
        }

        /**
         * Handle key presses when editing a note
         */
        protected bool on_key_press_notes_editor(Gtk.Widget source, Gdk.EventKey key) {
            if (key.keyval == Gdk.Key.Escape) { /* Escape */
                var this_note = this.notes_editor.buffer.text;
                this.notes_editor.editable = false;
                this.notes_editor.cursor_visible = false;
                this.metadata.set_note(this_note,
                    this.controller.current_slide_number);
                this.controller.set_ignore_input_events(false);
#if MDVIEW
                this.mdview.render(this_note,
                    this.metadata.get_disable_markdown());
                this.notes_stack.set_visible_child_name("mdview");
#endif
                return true;
            } else {
                return false;
            }
        }

        /**
         * Update the text of the current note
         */
        protected void update_note() {
            string this_note = this.metadata.get_note(
                this.controller.current_slide_number);
            this.notes_editor.buffer.text = this_note;
#if MDVIEW
            // render the note
            this.mdview.render(this_note, this.metadata.get_disable_markdown());
#endif
        }

        protected void show_overview() {
            // Ignore events coming from the presentation view
            if (!this.is_active) {
                return;
            }

            this.overview.current_slide = this.controller.current_user_slide_number;
            this.slide_stack.set_visible_child_name("overview");
            this.controller.set_ignore_input_events(true);
        }

        protected void hide_overview() {
            this.slide_stack.set_visible_child_name("slides");
            this.controller.set_ignore_input_events(false);
        }

        public bool is_overview_shown() {
            return (this.slide_stack.get_visible_child() == this.overview);
        }

        /**
         * Increase font sizes for Widgets
         */
        public void increase_font_size() {
            int font_size = this.metadata.get_font_size();
            font_size += 2;
            this.metadata.set_font_size(font_size);
            this.apply_font_size(font_size);
        }

        /**
         * Decrease font sizes for Widgets
         */
        public void decrease_font_size() {
            int font_size = this.metadata.get_font_size();
            font_size -= 2;
            if (font_size < 2) {
                font_size = 2;
            }
            this.metadata.set_font_size(font_size);
            this.apply_font_size(font_size);
        }

        private void apply_font_size(int size) {
            const string text_css_template = "#notesView { font-size: %dpt; }";
            var css = text_css_template.printf(size);

            try {
                css_provider.load_from_data(css, -1);
            } catch (Error e) {
                GLib.printerr("Warning: failed to set CSS for notes.\n");
            }
#if MDVIEW
            // 20pt is set in notes.css
            var mdview_zoom = size/20.0;
            this.mdview.apply_zoom(mdview_zoom);
#endif
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

        public void show_qrcode_window(bool onoff) {
            if (onoff) {
                this.slide_stack.set_visible_child_name("qrcode");
                this.slide_stack.get_child_by_name("qrcode").grab_focus();
                this.controller.set_ignore_input_events(true);
            } else {
                this.slide_stack.set_visible_child_name("slides");
                this.controller.set_ignore_input_events(false);
            }
        }
    }
}
