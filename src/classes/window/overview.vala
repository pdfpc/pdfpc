/**
 * Presentater window
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
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

using Gtk;
using Gdk;

using pdfpc;

namespace pdfpc.Window {
    /**
     * An overview of all the slides in the form of a table
     */
    public class Overview: Gtk.ScrolledWindow {

        /*
         * The store of all the slides.
         */
        protected ListStore slides;
        /*
         * The view of the above.
         */
        protected IconView slides_view;

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

        /*
         * The aspect ratio of the first slide.  We assume all slides share the
         * same aspect ratio.
         */
        protected double aspect_ratio;

        /*
         * The maximal size of the slides_view.
         */
        protected int max_width = -1;
        protected int max_height = -1;

        /*
         * The currently selected slide.
         */
        private int _current_slide = 0;
        public int current_slide {
            get { return _current_slide; }
            set { var path = new TreePath.from_indices(value);
                  this.slides_view.select_path(path);
                  // _current_slide set in on_selection_changed, below
                  this.slides_view.set_cursor(path, null, false);
                }
        }

        /*
         * When the section changes, we need to update the current slide number.
         * Also, make sure we don't end up with no selection.
         */
        public void on_selection_changed(Gtk.Widget source) {
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
            this.slides = new ListStore(1, typeof(Pixbuf));
            this.slides_view = new IconView.with_model(this.slides);
            this.slides_view.selection_mode = SelectionMode.SINGLE;
            var renderer = new CellRendererHighlight();
            this.slides_view.pack_start(renderer, true);
            this.slides_view.add_attribute(renderer, "pixbuf", 0);
            this.slides_view.set_item_padding(0);
            this.add(this.slides_view);
            this.show_all();

            Color black;
            Color white;
            Color.parse("black", out black);
            Color.parse("white", out white);
            this.slides_view.modify_base(StateType.NORMAL, black);
            Gtk.Scrollbar vscrollbar = (Gtk.Scrollbar) this.get_vscrollbar();
            vscrollbar.modify_bg(StateType.NORMAL, white);
            vscrollbar.modify_bg(StateType.ACTIVE, black);
            vscrollbar.modify_bg(StateType.PRELIGHT, white);

            this.metadata = metadata;
            this.presentation_controller = presentation_controller;
            this.presenter = presenter;

            this.slides_view.motion_notify_event.connect( this.presenter.on_mouse_move );
            this.slides_view.motion_notify_event.connect( this.on_mouse_move );
            this.slides_view.button_release_event.connect( this.on_mouse_release );
            this.slides_view.key_press_event.connect( this.on_key_press );
            this.slides_view.selection_changed.connect( this.on_selection_changed );
            this.parent_set.connect( this.on_parent_set );

            this.aspect_ratio = this.metadata.get_page_width() / this.metadata.get_page_height();
        }

        public void set_available_space(int width, int height) {
            this.max_width = width;
            this.max_height = height;
            this.fill_structure();
        }

        /*
         * Due to a change, the Overview is no longer shown or hidden; instead, its
         * parent is.  So we need to connect to its parent's show and hide signals.
         * But we can't do that until the parent has been set.  Thus this signal
         * handler.  Note that if the Overview is reparented, it will still be
         * connected to signals from its old parent.  So don't do that.
         */
        public void on_parent_set(Widget? old_parent) {
            if (this.parent != null) {
                this.parent.show.connect( this.on_show );
                this.parent.hide.connect( this.on_hide );
            }
        }

        /**
         * Get keyboard focus.
         */
        public void on_show() {
            this.slides_view.grab_focus();
        }

        /*
         * Recalculate the structure, if needed.
         */
        public void on_hide() {
            if (this.n_slides != this.last_structure_n_slides)
                this.fill_structure();
        }

        /**
         * Figure out the sizes for the icons, and create entries in slides
         * for all the slides.
         */
        protected void fill_structure() {
            if (this.max_width == -1)
                return;
            
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
                                         * this.aspect_ratio);  // floor so that later round
                                                                // doesn't increase height
                if (widthy < Options.min_overview_width)
                    break;
                
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
            this.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            this.target_height = (int)Math.round(this.target_width / this.aspect_ratio);
            rows = (int)Math.ceil((float)this.n_slides / this.slides_view.columns);
            int full_height = rows*(this.target_height + 2*padding + 2*row_spacing) + 2*margin;
            if (full_height > this.max_height)
                full_height = this.max_height;
            this.set_size_request(-1, full_height);

            this.last_structure_n_slides = this.n_slides;

            this.slides.clear();
            var pixbuf = new Pixbuf(Colorspace.RGB, true, 8, this.target_width, this.target_height);
            pixbuf.fill(0x7f7f7fff);
            var iter = TreeIter();
            for (int i=0; i<this.n_slides; i++) {
                this.slides.append(out iter);
                this.slides.set_value(iter, 0, pixbuf);
            }

            this.fill_previews();
        }

        /**
         * Fill the previews (only if we have a cache and we are displayed).
         * The size of the icons should be known already
         *
         * This is done in a progressive way (one slide at a time) instead of
         * all the slides in one go to provide some progress feedback to the
         * user.
         */
        protected void fill_previews() {
            if (this.idle_id != 0)
                Source.remove(idle_id);
            this.next_undone_preview = 0;
            this.idle_id = GLib.Idle.add(this._fill_previews);
        }
        
        protected bool _fill_previews() {
            if (this.cache == null || this.next_undone_preview >= this.n_slides)
                return false;

            // We get the dimensions from the first button and first slide,
            // should be the same for all
            int pixmap_width, pixmap_height;
            this.cache.retrieve(0).get_size(out pixmap_width, out pixmap_height);
            var pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB, true, 8, pixmap_width, pixmap_height);
            Gdk.pixbuf_get_from_drawable(pixbuf,
                this.cache.retrieve(metadata.user_slide_to_real_slide(this.next_undone_preview)),
                null, 0, 0, 0, 0, pixmap_width, pixmap_height);
            var pixbuf_scaled = pixbuf.scale_simple(this.target_width, this.target_height,
                                                    Gdk.InterpType.BILINEAR);

            var iter = TreeIter();
            this.slides.get_iter_from_string(out iter, @"$(this.next_undone_preview)");
            this.slides.set_value(iter, 0, pixbuf_scaled);

            return (++this.next_undone_preview < this.n_slides);
        }

        /**
         * Gives the cache to retrieve the images from. The caching process
         * itself should already be finished.
         */
        public void set_cache(Renderer.Cache.Base cache) {
            this.cache = cache;
            this.fill_previews();
        }
        
        /**
         * Set the number of slides. If it is different to what we know, it
         * triggers a rebuilding of the widget.
         */
        public void set_n_slides(int n) {
            if ( n != this.n_slides ) {
                var currently_selected = this.current_slide;
                this.n_slides = n;
                this.fill_structure();
                if ( currently_selected >= this.n_slides )
                    currently_selected = this.n_slides - 1;
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
            var iter = TreeIter();
            this.slides.get_iter_from_string(out iter, @"$(this.current_slide)");
            this.slides.remove(iter);
            if (this.current_slide >= this.n_slides)
                this.current_slide = this.n_slides - 1;
        }

        /**
         * We handle some "navigation" key presses ourselves. Others are left to
         * the standard IconView controls, the rest are passed back to the
         * PresentationController.
         */
        public bool on_key_press(Gtk.Widget source, EventKey key) {
            bool handled = false;
            switch ( key.keyval ) {
                case 0xff51: /* Cursor left */
                case 0xff55: /* Page Up */
                    if ( this.current_slide > 0)
                        this.current_slide -= 1;
                    handled = true;
                    break;
                case 0xff53: /* Cursor right */
                case 0xff56: /* Page down */
                    if ( this.current_slide < this.n_slides - 1 )
                        this.current_slide += 1;
                    handled = true;
                    break;
                case 0xff0d: /* Return */
                    this.presentation_controller.goto_user_page(this.current_slide + 1);
                    break;
            }
                    
            return handled;
        }

        /*
         * Update the selection when the mouse moves over a new slides.
         */
        public bool on_mouse_move(Gtk.Widget source, EventMotion event) {
            TreePath path;
            path = this.slides_view.get_path_at_pos((int)event.x, (int)event.y);
            if (path != null && path.get_indices()[0] != this.current_slide)
                this.current_slide = path.get_indices()[0];
            return false;
        }

        /*
         * Go to selected slide when the mouse button is released.  On a simple
         * click, the button_press event will have set the current slide.  On
         * a drag, the current slide will have been updated by the motion.
         */
        public bool on_mouse_release(EventButton event) {
            if (event.button == 1)
                this.presentation_controller.goto_user_page(this.current_slide + 1);
            return false;
        }
    }

    /*
     * Render a pixbuf that is slightly shaded, unless it is the selected one.
     */
    public class CellRendererHighlight: CellRendererPixbuf {
        
        public override void render(Gdk.Window window, Widget widget,
                                    Rectangle background_area, Rectangle cell_area,
                                    Rectangle expose_area, CellRendererState flags) {
            base.render(window, widget, background_area, cell_area, expose_area, flags);
            if (flags != CellRendererState.SELECTED) {
                var cr = Gdk.cairo_create(window);
                Gdk.cairo_rectangle(cr, expose_area);
                cr.clip();
                
                Gdk.cairo_rectangle(cr, cell_area);
                cr.set_source_rgba(0,0,0,0.2);
                cr.fill();
            }
        }
    }
}
