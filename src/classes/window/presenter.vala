/**
 * Presentater window
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2012, 2015 Andreas Bilke
 * Copyright 2013 Gabor Adam Toth
 * Copyright 2015 Andy Barry
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
         * The registered PresentationController
         */
        public PresentationController presentation_controller { get; protected set; }

        /**
         * Only handle links and annotations on the current_view
         */
        public View.Pdf main_view {
            get {
                return this.current_view as View.Pdf;
            }
        }

        /**
         * View showing the current slide
         */
        protected View.Base current_view;

        /**
         * View showing a preview of the next slide
         */
        protected View.Base next_view;

        /**
         * Small views for (non-user) next slides
         */
        protected View.Base strict_next_view;
        protected View.Base strict_prev_view;

        /**
         * Timer for the presenation
         */
        protected TimerLabel? timer;

        /**
         * Slide progress label ( eg. "23/42" )
         */
        protected Gtk.Entry slide_progress;

        protected Gtk.ProgressBar prerender_progress;

        /**
         * Indication that the slide is blanked (faded to black)
         */
        protected Gtk.Image blank_icon;

        /**
         * Indication that the presentation display is frozen
         */
        protected Gtk.Image frozen_icon;

        /**
         * Indication that the timer is paused
         */
        protected Gtk.Image pause_icon;

        /**
         * Text box for displaying notes for the slides
         */
        protected Gtk.TextView notes_view;

        /**
         * The overview of slides
         */
        protected Overview overview = null;

        /**
         * The Stack containing the slides view and the overview.
         */
        protected Gtk.Stack slide_stack;

        /**
         * Number of slides inside the presentation
         *
         * This value is needed a lot of times therefore it is retrieved once
         * and stored here for performance and readability reasons.
         */
        protected uint slide_count;

        /**
         * Metadata of the slides
         */
        protected Metadata.Pdf metadata;

        /**
         * Base constructor instantiating a new presenter window
         */
        public Presenter(Metadata.Pdf metadata, int screen_num,
            PresentationController presentation_controller) {
            base(screen_num);
            this.role = "presenter";

            this.destroy.connect((source) => presentation_controller.quit());

            this.presentation_controller = presentation_controller;
            this.presentation_controller.update_request.connect(this.update);
            this.presentation_controller.edit_note_request.connect(this.edit_note);
            this.presentation_controller.ask_goto_page_request.connect(this.ask_goto_page);
            this.presentation_controller.show_overview_request.connect(this.show_overview);
            this.presentation_controller.hide_overview_request.connect(this.hide_overview);

            this.metadata = metadata;

            // We need the value of 90% height a lot of times. Therefore store it
            // in advance
            var bottom_position = (int) Math.floor(this.screen_geometry.height * 0.9);
            var bottom_height = this.screen_geometry.height - bottom_position;

            // In most scenarios the current slide is displayed bigger than the
            // next one. The option current_size represents the width this view
            // should use as a percentage value. The maximal height is 90% of
            // the screen, as we need a place to display the timer and slide
            // count.
            Gdk.Rectangle current_scale_rect;
            int current_allocated_width = (int) Math.floor(
                this.screen_geometry.width * Options.current_size / (double) 100);
            this.current_view = new View.Pdf.from_metadata(
                metadata,
                current_allocated_width,
                (int) Math.floor(0.8 * bottom_position),
                Metadata.Area.NOTES,
                Options.black_on_end,
                true,
                this.presentation_controller,
                out current_scale_rect
            );

            // The next slide is right to the current one and takes up the
            // remaining width
            //Requisition cv_requisition;
            //this.current_view.size_request(out cv_requisition);
            //current_allocated_width = cv_requisition.width;
            Gdk.Rectangle next_scale_rect;
            var next_allocated_width = this.screen_geometry.width - current_allocated_width - 4;
            // We leave a bit of margin between the two views
            this.next_view = new View.Pdf.from_metadata(
                metadata,
                next_allocated_width,
                (int) Math.floor(0.7 * bottom_position),
                Metadata.Area.CONTENT,
                true,
                false,
                this.presentation_controller,
                out next_scale_rect
            );

            this.strict_next_view = new View.Pdf.from_metadata(
                metadata,
                (int) Math.floor(0.5 * current_allocated_width),
                (int) Math.floor(0.19 * bottom_position) - 2,
                Metadata.Area.CONTENT,
                true,
                false,
                this.presentation_controller,
                out next_scale_rect
            );
            this.strict_prev_view = new View.Pdf.from_metadata(
                metadata,
                (int) Math.floor(0.5 * current_allocated_width),
                (int) Math.floor(0.19 * bottom_position) - 2,
                Metadata.Area.CONTENT,
                true,
                false,
                this.presentation_controller,
                out next_scale_rect
            );

            // TextView for notes in the slides
            var notes_font = Pango.FontDescription.from_string("Verdana");
            notes_font.set_size((int) Math.floor(20 * 0.75) * Pango.SCALE);
            this.notes_view = new Gtk.TextView();
            this.notes_view.editable = false;
            this.notes_view.cursor_visible = false;
            this.notes_view.wrap_mode = Gtk.WrapMode.WORD;
            this.notes_view.override_font(notes_font);
            this.notes_view.buffer.text = "";
            this.notes_view.key_press_event.connect(this.on_key_press_notes_view);

            // Initial font needed for the labels
            // We approximate the point size using pt = px * .75
            var font = Pango.FontDescription.from_string("Verdana");
            font.set_size((int) Math.floor(bottom_height * 0.8 * 0.75) * Pango.SCALE);

            // The countdown timer is centered in the 90% bottom part of the screen
            // It takes 3/4 of the available width
            this.timer = this.presentation_controller.getTimer();
            this.timer.set_justify(Gtk.Justification.CENTER);
            this.timer.override_font(font);


            // The slide counter is centered in the 90% bottom part of the screen
            // It takes 1/4 of the available width on the right
            this.slide_progress = new Gtk.Entry();
            this.slide_progress.set_alignment(1f);
            this.slide_progress.override_font(font);
            this.slide_progress.sensitive = false;
            this.slide_progress.has_frame = false;
            this.slide_progress.key_press_event.connect(this.on_key_press_slide_progress);

            this.prerender_progress = new Gtk.ProgressBar();
            this.prerender_progress.show_text = true;
            this.prerender_progress.text = "Prerendering...";
            this.prerender_progress.override_font(notes_font);
            this.prerender_progress.no_show_all = true;

            int icon_height = bottom_height - 10;

            this.blank_icon = this.load_icon("blank.svg", icon_height);
            this.frozen_icon = this.load_icon("snow.svg", icon_height);
            this.pause_icon = this.load_icon("pause.svg", icon_height);

            this.add_events(Gdk.EventMask.KEY_PRESS_MASK);
            this.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            this.add_events(Gdk.EventMask.SCROLL_MASK);

            this.key_press_event.connect(this.presentation_controller.key_press);
            this.button_press_event.connect(this.presentation_controller.button_press);
            this.scroll_event.connect(this.presentation_controller.scroll);

            // Store the slide count once
            this.slide_count = metadata.get_slide_count();

            this.overview = new Overview(this.metadata, this.presentation_controller, this);
            this.overview.set_n_slides(this.presentation_controller.user_n_slides);
            this.presentation_controller.set_overview(this.overview);
            this.presentation_controller.register_controllable(this);

            // Enable the render caching if it hasn't been forcefully disabled.
            if (!Options.disable_caching) {
                ((Renderer.Caching) this.current_view.get_renderer()).cache =
                    Renderer.Cache.create(metadata);
                ((Renderer.Caching) this.next_view.get_renderer()).cache =
                    Renderer.Cache.create(metadata);
                ((Renderer.Caching) this.strict_next_view.get_renderer()).cache =
                    Renderer.Cache.create(metadata);
                ((Renderer.Caching)this.strict_prev_view.get_renderer()).cache =
                    Renderer.Cache.create(metadata);
            }

            this.build_layout();
        }

        public override void show() {
            base.show();
            Gtk.Allocation allocation;
            this.get_allocation(out allocation);
            this.overview.set_available_space(allocation.width,
                (int) Math.floor(allocation.height * 0.9));
        }

        protected Gtk.Image load_icon(string filename, int icon_height) {

            // attempt to load from a local path (if the user hasn't installed)
            // if that fails, attempt to load from the global path
            string load_icon_path = Path.build_filename(Paths.SOURCE_PATH, "icons", filename);
            File icon_file = File.new_for_path(load_icon_path);
            if (!icon_file.query_exists()) {
                load_icon_path = Path.build_filename(Paths.ICON_PATH, filename);
            }

            Gtk.Image icon;
            try {
                Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.from_file_at_size(load_icon_path,
                    (int) Math.floor(1.06 * icon_height), icon_height);
                icon = new Gtk.Image.from_pixbuf(pixbuf);
                icon.no_show_all = true;
            } catch (Error e) {
                stderr.printf("Warning: Could not load icon %s (%s)\n", load_icon_path, e.message);
                icon = new Gtk.Image.from_icon_name("image-missing", Gtk.IconSize.LARGE_TOOLBAR);
            }
            return icon;
        }

        protected void build_layout() {
            Gtk.Box slide_views = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);

            var strict_views = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            strict_views.pack_start(this.strict_prev_view, false, false, 0);
            strict_views.pack_end(this.strict_next_view, false, false, 0);

            this.current_view.halign = Gtk.Align.CENTER;
            this.current_view.valign = Gtk.Align.CENTER;

            var current_view_and_stricts = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            current_view_and_stricts.pack_start(current_view, false, false, 2);
            current_view_and_stricts.pack_start(strict_views, false, false, 2);


            slide_views.pack_start(current_view_and_stricts, true, true, 0);

            var nextViewWithNotes = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            this.next_view.halign = Gtk.Align.CENTER;
            this.next_view.valign = Gtk.Align.CENTER;
            nextViewWithNotes.pack_start(next_view, false, false, 0);
            var notes_sw = new Gtk.ScrolledWindow(null, null);
            notes_sw.add(this.notes_view);
            notes_sw.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            nextViewWithNotes.pack_start(notes_sw, true, true, 5);
            slide_views.pack_start(nextViewWithNotes, true, true, 0);

            this.overview.halign = Gtk.Align.CENTER;
            this.overview.valign = Gtk.Align.CENTER;

            this.slide_stack = new Gtk.Stack();
            this.slide_stack.add_named(slide_views, "slides");
            this.slide_stack.add_named(this.overview, "overview");
            this.slide_stack.homogeneous = true;

            var bottom_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            bottom_row.homogeneous = true;

            var status = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            status.pack_start(this.blank_icon, false, false, 0);
            status.pack_start(this.frozen_icon, false, false, 0);
            status.pack_start(this.pause_icon, false, false, 0);

            this.timer.halign = Gtk.Align.CENTER;
            this.timer.valign = Gtk.Align.CENTER;

            var progress_alignment = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            progress_alignment.pack_end(this.slide_progress);
            this.prerender_progress.vexpand = false;
            this.prerender_progress.valign = Gtk.Align.CENTER;
            progress_alignment.pack_start(this.prerender_progress, true, true, 0);

            bottom_row.pack_start(status, true, true, 0);
            bottom_row.pack_start(this.timer, true, true, 0);
            bottom_row.pack_end(progress_alignment, true, true, 0);

            Gtk.Box full_layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            full_layout.set_size_request(this.screen_geometry.width, this.screen_geometry.height);
            full_layout.pack_start(this.slide_stack, true, true, 0);
            full_layout.pack_end(bottom_row, false, false, 0);

            this.add(full_layout);
        }

        /**
         * Update the slide count view
         */
        protected void update_slide_count() {
            this.custom_slide_count(this.presentation_controller.current_user_slide_number + 1);
        }

        public void custom_slide_count(int current) {
            int total = this.presentation_controller.get_end_user_slide();
            this.slide_progress.set_text("%d/%u".printf(current, total));
        }

        public void update() {
            int current_slide_number = this.presentation_controller.current_slide_number;
            int current_user_slide_number = this.presentation_controller.current_user_slide_number;
            try {
                this.current_view.display(current_slide_number);
                this.next_view.display(this.metadata.user_slide_to_real_slide(
                    current_user_slide_number + 1));
                if (this.presentation_controller.skip_next()) {
                    this.strict_next_view.display(current_slide_number + 1, true);
                } else {
                    this.strict_next_view.fade_to_black();
                }
                if (this.presentation_controller.skip_previous()) {
                    this.strict_prev_view.display(current_slide_number - 1, true);
                } else {
                    this.strict_prev_view.fade_to_black();
                }
            }
            catch( Renderer.RenderError e ) {
                error("The pdf page %d could not be rendered: %s", current_slide_number, e.message);
            }
            this.update_slide_count();
            this.update_note();
            if (this.timer.is_paused())
                this.pause_icon.show();
            else
                this.pause_icon.hide();
            if (this.presentation_controller.faded_to_black)
                this.blank_icon.show();
            else
                this.blank_icon.hide();
            if (this.presentation_controller.frozen)
                this.frozen_icon.show();
            else
                this.frozen_icon.hide();
            this.faded_to_black = false;
        }

        /**
         * Display a specific page
         */
        public void goto_page(int page_number) {
            try {
                this.current_view.display(page_number);
                this.next_view.display(page_number + 1);
            } catch( Renderer.RenderError e ) {
                error("The pdf page %d could not be rendered: %s", page_number, e.message);
            }

            this.update_slide_count();
            this.update_note();
            this.blank_icon.hide();
        }

        /**
         * Ask for the page to jump to
         */
        public void ask_goto_page() {
            this.slide_progress.set_text("/%u".printf(this.presentation_controller.user_n_slides));
            this.slide_progress.sensitive = true;
            this.slide_progress.grab_focus();
            this.slide_progress.set_position(0);
            this.presentation_controller.set_ignore_input_events(true);
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
                this.presentation_controller.set_ignore_input_events(false);
                if (destination != 0)
                    this.presentation_controller.goto_user_page(destination);
                else
                    this.update_slide_count(); // Reset the display we had before
                return true;
            } else {
                return false;
            }
        }

        /**
         * Edit a note. Basically give focus to notes_view
         */
        public void edit_note() {
            this.notes_view.editable = true;
            this.notes_view.cursor_visible = true;
            this.notes_view.grab_focus();
            this.presentation_controller.set_ignore_input_events(true);
        }

        /**
         * Handle key presses when editing a note
         */
        protected bool on_key_press_notes_view(Gtk.Widget source, Gdk.EventKey key) {
            if (key.keyval == Gdk.Key.Escape) { /* Escape */
                this.notes_view.editable = false;
                this.notes_view.cursor_visible = false;
                this.metadata.get_notes().set_note(this.notes_view.buffer.text,
                    this.presentation_controller.current_user_slide_number);
                this.presentation_controller.set_ignore_input_events(false);
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
                this.presentation_controller.current_user_slide_number);
            this.notes_view.buffer.text = this_note;
        }

        public void show_overview() {
            this.slide_stack.set_visible_child_name("overview");
            this.overview.ensure_focus();
            this.overview.current_slide = this.presentation_controller.current_user_slide_number;
        }

        public void hide_overview() {
            this.slide_stack.set_visible_child_name("slides");
            this.overview.ensure_structure();
        }

        /**
         * Take a cache observer and register it with all prerendering Views
         * shown on the window.
         *
         * Furthermore it is taken care of to add the cache observer to this window
         * for display, as it is a Image widget after all.
         */
        public void set_cache_observer(CacheStatus observer) {
            var current_prerendering_view = this.current_view as View.Prerendering;
            if (current_prerendering_view != null) {
                observer.monitor_view(current_prerendering_view);
            }
            var next_prerendering_view = this.next_view as View.Prerendering;
            if (next_prerendering_view != null) {
                observer.monitor_view(next_prerendering_view);
            }

            observer.update_progress.connect(this.prerender_progress.set_fraction);
            observer.update_complete.connect(this.prerender_finished);
            this.prerender_progress.show();
        }

        public void prerender_finished() {
            this.prerender_progress.opacity = 0;  // hide() causes a flash for re-layout.
            this.overview.set_cache(((Renderer.Caching) this.next_view.get_renderer()).cache);
        }
    }
}
