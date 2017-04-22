/**
 * Presentater window
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2015 Andreas Bilke
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
     * An overview of all the slides in the form of a table
     */
    public class Overview: Gtk.ScrolledWindow {

        /*
         * The store of all the slides.
         */
        protected Gtk.ListStore slides;
        /*
         * The view of the above.
         */
        protected Gtk.IconView slides_view;

        /**
         * We will need the metadata mainly for converting from user slides to
         * real slides.
         */
        protected Metadata.Pdf metadata;

        /**
         * How many (user) slides we have.
         */
        protected int n_slides = 0;

        protected int last_structure_n_slides = 0;

        /**
         * The target height and width of the scaled images, a bit smaller than
         * the button dimensions to allow some margin
         */
        protected int target_width;
        protected int target_height;

        /**
         * We render the previews one at a time in idle times.
         */
        protected int next_undone_preview = 0;
        protected uint idle_id = 0;

        /**
         * The cache we get the images from. It is a reference because the user
         * can deactivate the cache on the command line. In this case we show
         * just slide numbers, which is not really so much useful.
         */
        protected Renderer.Cache.Base? cache = null;

        /**
         * The presentation controller
         */
        protected PresentationController presentation_controller;

        /**
         * The presenter. We have a reference here to update the current slide
         * display.
         */
        protected Presenter presenter;

        /**
         * The maximal size of the slides_view.
         */
        protected int max_width = -1;
        protected int max_height = -1;

        /**
         * The currently selected slide.
         */
        private int _current_slide = 0;
        public int current_slide {
            get { return _current_slide; }
            set { var path = new Gtk.TreePath.from_indices(value);
                  this.slides_view.select_path(path);
                  // _current_slide set in on_selection_changed, below
                  this.slides_view.set_cursor(path, null, false);
                }
        }

        /**
         * The used cell renderer, for later usage
         */
        private CellRendererHighlight renderer;

        /*
         * When the section changes, we need to update the current slide number.
         * Also, make sure we don't end up with no selection.
         */
        public void on_selection_changed() {
            var ltp = this.slides_view.get_selected_items();
            if (ltp != null) {
                var tp = ltp.data;
                if (tp.get_indices() != null) {  // Seg fault if we save tp.get_indices locally
                    this._current_slide = tp.get_indices()[0];
                    this.presenter.custom_slide_count(this._current_slide + 1);
                    return;
                }
            }
            // If there's no selection, reset the old one
            this.current_slide = this._current_slide;
        }

        /**
         * Constructor
         */
        public Overview( Metadata.Pdf metadata, PresentationController presentation_controller, Presenter presenter ) {
            this.get_style_context().add_class("overviewWindow");

            this.slides = new Gtk.ListStore(1, typeof(int));
            this.slides_view = new Gtk.IconView.with_model(this.slides);
            this.slides_view.selection_mode = Gtk.SelectionMode.SINGLE;
            this.slides_view.halign = Gtk.Align.CENTER;
            this.renderer = new CellRendererHighlight();
            this.renderer.metadata = metadata;
            Gtk.StyleContext style_context = this.get_style_context();
            Pango.FontDescription font_description;
            style_context.get(style_context.get_state(), "font", out font_description, null);
            this.renderer.font_description = font_description;

            this.slides_view.pack_start(renderer, true);
            this.slides_view.add_attribute(renderer, "slide_id", 0);
            this.slides_view.set_item_padding(0);
            this.slides_view.show();
            this.add(this.slides_view);

            this.metadata = metadata;
            this.presentation_controller = presentation_controller;
            this.presenter = presenter;

            this.slides_view.motion_notify_event.connect(this.presenter.on_mouse_move);
            this.slides_view.motion_notify_event.connect(this.on_mouse_move);
            this.slides_view.button_release_event.connect(this.on_mouse_release);
            this.slides_view.key_press_event.connect(this.on_key_press);
            this.slides_view.selection_changed.connect(this.on_selection_changed);
            this.key_press_event.connect((event) => this.slides_view.key_press_event(event));

        }

        public void set_available_space(int width, int height) {
            this.max_width = width;
            this.max_height = height;
            this.prepare_layout();
        }

        /**
         * Get keyboard focus.  This requires that the window has focus.
         */
        public void ensure_focus() {
            Gtk.Window top = this.get_toplevel() as Gtk.Window;
            if (top != null && !top.has_toplevel_focus) {
                top.present();
            }
            this.slides_view.grab_focus();
        }

        /*
         * Recalculate the structure, if needed.
         */
        public void ensure_structure() {
            if (this.n_slides != this.last_structure_n_slides) {
                this.prepare_layout();
            }
        }

        /**
         * Figure out the sizes for the icons, and create entries in slides
         * for all the slides.
         */
        protected void prepare_layout() {
            if (this.max_width == -1) {
                return;
            }

            double aspect_ratio = this.metadata.get_page_width() / this.metadata.get_page_height();

            this.slides_view.set_margin(0);

            var margin = this.slides_view.get_margin();
            var padding = this.slides_view.get_item_padding() + 1; // Additional mystery pixel
            var row_spacing = this.slides_view.get_row_spacing();
            var col_spacing = this.slides_view.get_column_spacing();

            var eff_max_width = this.max_width - 2 * margin;
            var eff_max_height = this.max_height - 2 * margin;
            int cols = eff_max_width / (Options.min_overview_width + 2 * padding + col_spacing);
            int widthx, widthy, min_width, rows;
            int tc = 0;

            // Search for the layout with the widest icons.  We do this by considering
            // layouts with different numbers of columns, and figuring the maximum
            // width for the icon so that all the icons fit both horizontally and
            // vertically.  We start with the largest number of columns that fit the
            // icons at the minimum allowed width, and we decrease the number of columns
            // until we cannot fit the icons vertically at the minimal allowed size.
            // Note that there may be NO solution, in which case target_width == 0.
            this.target_width = 0;
            while (cols > 0) {
                widthx = eff_max_width / cols - 2*padding - 2*col_spacing;
                rows = (int)Math.ceil((float)this.n_slides / cols);
                widthy = (int)Math.floor((eff_max_height / rows - 2*padding - 2*row_spacing)
                                         * aspect_ratio);  // floor so that later round
                                                           // doesn't increase height
                if (widthy < Options.min_overview_width) {
                    break;
                }

                min_width = widthx < widthy ? widthx : widthy;
                if (min_width >= this.target_width) {  // If two layouts give the same width
                    this.target_width = min_width;     // (which happens when they're limited
                    tc = cols;                         // by height), prefer the one with fewer
                }                                      // columns for a more filled block.
                cols -= 1;
            }
            if (this.target_width < Options.min_overview_width) {
                this.target_width = Options.min_overview_width;
                this.slides_view.columns = (eff_max_width - 20) // Guess for scrollbar width
                    / (Options.min_overview_width + 2 * padding + col_spacing);
            } else {
                this.slides_view.columns = tc;
            }
            this.set_policy(Gtk.PolicyType.ALWAYS, Gtk.PolicyType.ALWAYS);
            this.target_height = (int)Math.round(this.target_width / aspect_ratio);
            rows = (int)Math.ceil((float)this.n_slides / this.slides_view.columns);
            int full_height = rows*(this.target_height + 2*padding + 2*row_spacing) + 2*margin;
            if (full_height > this.max_height) {
                full_height = this.max_height;
            }

            this.last_structure_n_slides = this.n_slides;

            this.renderer.slide_width = this.target_width;
            this.renderer.slide_height = this.target_height;

            this.slides.clear();
            var iter = Gtk.TreeIter();
            for (int i = 0; i < this.n_slides; i++) {
                this.slides.append(out iter);
                this.slides.set_value(iter, 0, i);
            }
        }

        /**
         * Gives the cache to retrieve the images from. The caching process
         * itself should already be finished.
         */
        public void set_cache(Renderer.Cache.Base cache) {
            this.cache = cache;
            this.renderer.cache = cache;
            // force redraw if the cache is there
            this.slides_view.queue_draw();
        }

        /**
         * Set the number of slides. If it is different to what we know, it
         * triggers a rebuilding of the widget.
         */
        public void set_n_slides(int n) {
            if (n != this.n_slides) {
                var currently_selected = this.current_slide;
                this.n_slides = n;
                this.prepare_layout();
                if (currently_selected >= this.n_slides) {
                    currently_selected = this.n_slides - 1;
                }
                this.current_slide = currently_selected;
            }
        }

        /**
         * Remove the current slide from the overview, and set the total number
         * of slides to the new value.  Perpare to regenerate the structure the
         * next time the overview is hidden.
         */
        public void remove_current(int newn) {
            this.n_slides = newn;
            var iter = Gtk.TreeIter();
            this.slides.get_iter_from_string(out iter, @"$(this.current_slide)");
#if VALA_0_36
            // Updated bindings in Vala 0.36: "iter" param of ListStore.remove() marked as ref
            this.slides.remove(ref iter);
#else
            this.slides.remove(iter);
#endif
            if (this.current_slide >= this.n_slides) {
                this.current_slide = this.n_slides - 1;
            }
        }

        /**
         * We handle some "navigation" key presses ourselves. Others are left to
         * the standard IconView controls, the rest are passed back to the
         * PresentationController.
         */
        public bool on_key_press(Gtk.Widget source, Gdk.EventKey key) {
            bool handled = false;
            switch (key.keyval) {
                case 0xff51: /* Cursor left */
                case 0xff55: /* Page Up */
                    if (this.current_slide > 0) {
                        this.current_slide -= 1;
                    }
                    handled = true;
                    break;
                case 0xff53: /* Cursor right */
                case 0xff56: /* Page down */
                    if (this.current_slide < this.n_slides - 1) {
                        this.current_slide += 1;
                    }
                    handled = true;
                    break;
                case 0xff0d: /* Return */
                    bool gotoFirst = (key.state & Gdk.ModifierType.SHIFT_MASK) != 0;
                    this.presentation_controller.goto_user_page(this.current_slide + 1, !gotoFirst);
                    handled = true;
                    break;
            }

            return handled;
        }

        /*
         * Update the selection when the mouse moves over a new slides.
         */
        public bool on_mouse_move(Gtk.Widget source, Gdk.EventMotion event) {
            Gtk.TreePath path;
            path = this.slides_view.get_path_at_pos((int)event.x, (int)event.y);
            if (path != null && path.get_indices()[0] != this.current_slide) {
                this.current_slide = path.get_indices()[0];
            }
            return false;
        }

        /*
         * Go to selected slide when the mouse button is released.  On a simple
         * click, the button_press event will have set the current slide.  On
         * a drag, the current slide will have been updated by the motion.
         */
        public bool on_mouse_release(Gdk.EventButton event) {
            if (event.button == 1) {
                bool gotoFirst = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0;
                this.presentation_controller.goto_user_page(this.current_slide + 1, !gotoFirst);
            }
            return false;
        }
    }

    /*
     * Render a surface that is slightly shaded, unless it is the selected one.
     */
    class CellRendererHighlight : Gtk.CellRenderer {
        public int slide_id { get; set; }

        public Renderer.Cache.Base? cache { get; set; }
        public Pango.FontDescription font_description { get; set; }
        public Metadata.Pdf metadata { get; set; }
        public int slide_width { get; set; }
        public int slide_height { get; set; }

        public override void get_size(Gtk.Widget widget, Gdk.Rectangle? cell_area,
                                      out int x_offset, out int y_offset,
                                      out int width, out int height) {
            x_offset = 0;
            y_offset = 0;
            width = this.slide_width;
            height = this.slide_height;
        }

        public override void render(Cairo.Context cr, Gtk.Widget widget,
                                    Gdk.Rectangle background_area, Gdk.Rectangle cell_area,
                                    Gtk.CellRendererState flags) {
            // nothing to show
            if (cache == null) {
                cr.set_source_rgba(0.5, 0.5, 0.5, 1);
                cr.rectangle(cell_area.x, cell_area.y, cell_area.width, cell_area.height);
                cr.fill();
            } else {
                var slide_to_fill = this.cache.retrieve(metadata.user_slide_to_real_slide(this.slide_id));
                double scale_factor = (double)slide_width/slide_to_fill.get_width();
                cr.scale(scale_factor, scale_factor);
                cr.set_source_surface(slide_to_fill, (double)cell_area.x/scale_factor, (double)cell_area.y/scale_factor);
                cr.paint();
                cr.scale(1.0/scale_factor, 1.0/scale_factor);
            }

            if ((flags & Gtk.CellRendererState.SELECTED) == 0) {
                cr.rectangle(cell_area.x, cell_area.y, cell_area.width, cell_area.height);
                cr.set_source_rgba(0, 0, 0, 0.4);
                cr.fill();
            }

            // draw slide number
            var layout = Pango.cairo_create_layout(cr);
            layout.set_font_description(this.font_description);
            layout.set_text(@"$(slide_id + 1)", -1);
            layout.set_width(cell_area.width);
            layout.set_alignment(Pango.Alignment.CENTER);

            Pango.Rectangle logical_extent;
            layout.get_pixel_extents(null, out logical_extent);
            cr.move_to(cell_area.x + (cell_area.width / 2), cell_area.y + (cell_area.height / 2) - (logical_extent.height / 2));

            if ((flags & Gtk.CellRendererState.SELECTED) == 0) {
                cr.set_source_rgba(0.7, 0.7, 0.7, 0.7);
            } else {
                cr.set_source_rgba(0.7, 0.7, 0.7, 0.2);
            }

            Pango.cairo_show_layout(cr, layout);
        }
    }
}
