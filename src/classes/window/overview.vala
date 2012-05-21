/**
 * Presentater window
 *
 * This file is part of pdf-presenter-console.
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

using org.westhoffswelt.pdfpresenter;

namespace org.westhoffswelt.pdfpresenter.Window {
    /**
     * An overview of all the slides in the form of a table
     */
    public class Overview: Gtk.Alignment {

        /*
         * The store of all the slides.
         */
        protected ListStore slides;
        /*
         * The view of the above.
         */
        protected IconView slides_view;

        /*
         * The ScrolledWindow containing slides_view.
         */
        protected ScrolledWindow sw;

        /**
         * We will need the metadata mainly for converting from user slides to
         * real slides.
         */
        protected Metadata.Pdf metadata;

        /**
         * How many (user) slides we have.
         */
        protected int n_slides = 0;

        /**
         * The target height and width of the scaled images, a bit smaller than
         * the button dimensions to allow some margin
         */
        protected int target_width;
        protected int target_height;

        /**
         * Are we displayed?
         */
        protected bool shown = false;

        /**
         * Because gtk only allocates sizes on demand, the building of the
         * buttons and the scaling of the preview must be done separately. Here
         * we keep track of what we have already done.
         */
        protected bool structure_done = false;
        protected int next_undone_preview = 0;

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
        protected int max_width;
        protected int max_height;

        /*
         * The currently selected slide.
         */
        protected int current_slide = 0;

        /**
         * Constructor
         */
        public Overview( Metadata.Pdf metadata, PresentationController presentation_controller, Presenter presenter ) {
            this.set(0.5f, 0.5f, 0, 0);

            this.sw = new ScrolledWindow(null, null);
            this.sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            this.slides = new ListStore(1, typeof(Pixbuf));
            this.slides_view = new IconView.with_model(this.slides);
            this.slides_view.selection_mode = SelectionMode.SINGLE;
            var renderer = new CellRendererHighlight();
            this.slides_view.pack_start(renderer, true);
            this.slides_view.add_attribute(renderer, "pixbuf", 0);
            this.slides_view.set_item_padding(0);
            this.sw.add(this.slides_view);
            this.add(this.sw);
            this.sw.show_all();

            Color black;
            Color white;
            Color.parse("black", out black);
            Color.parse("white", out white);
            this.slides_view.modify_base(StateType.NORMAL, black);
            Gtk.Scrollbar vscrollbar = (Gtk.Scrollbar) this.sw.get_vscrollbar();
            vscrollbar.modify_bg(StateType.NORMAL, white);
            vscrollbar.modify_bg(StateType.ACTIVE, black);
            vscrollbar.modify_bg(StateType.PRELIGHT, white);

            this.metadata = metadata;
            this.presentation_controller = presentation_controller;
            this.presenter = presenter;

            this.slides_view.motion_notify_event.connect( this.presenter.on_mouse_move );
            this.slides_view.key_press_event.connect( this.on_key_press );
            this.slides_view.selection_changed.connect( this.on_selection_changed );

            this.aspect_ratio = this.metadata.get_page_width() / this.metadata.get_page_height();
        }

        public void set_available_space(int width, int height) {
            this.max_width = width;
            this.max_height = height;
        }

        /**
         * Show the widget + build the structure if needed
         */
        public override void show() {
            base.show();
            this.shown = true;
            this.fill_structure();
            this.slides_view.grab_focus();
        }

        /**
         * Figure out the sizes for the icons, and create entries in slides
         * for all the slides.
         */
        protected void fill_structure() {
            if (!this.structure_done) {
                var margin = this.slides_view.get_margin();
                var padding = this.slides_view.get_item_padding()+1; // Additional mystery pixel
                var row_spacing = this.slides_view.get_row_spacing();
                var col_spacing = this.slides_view.get_column_spacing();
                
                var eff_max_width = this.max_width - 2 * margin + col_spacing;
                var eff_max_height = this.max_height - 2 * margin + row_spacing;
                int cols = eff_max_width / (Options.min_overview_width + 2 * padding + col_spacing);
                int widthx, widthy, min_width, rows;
                int tr = 0, tc = 0;
                
                this.target_width = 0;
                while (cols > 0) {
                    widthx = eff_max_width / cols - 2*padding - col_spacing;
                    rows = (int)Math.ceil((float)this.n_slides / cols);
                    widthy = (int)Math.floor((eff_max_height / rows - 2*padding - row_spacing)
                                             * this.aspect_ratio);  // floor so that later round
                                                                    // doesn't increase height
                    if (widthy < Options.min_overview_width)
                        break;
                    
                    min_width = widthx < widthy ? widthx : widthy;
                    if (min_width >= this.target_width) {
                        this.target_width = min_width;
                        tr = rows;
                        tc = cols;
                    }
                    cols -= 1;
                }
                if (this.target_width < Options.min_overview_width)
                    this.target_width = Options.min_overview_width;
                this.target_height = (int)Math.round(this.target_width / this.aspect_ratio);
                if (tr > 0) {
                    this.sw.set_size_request(tc * (this.target_width + 2*padding + col_spacing)
                                             + 2*margin - col_spacing,
                                            tr * (this.target_height + 2*padding + row_spacing)
                                             + 2*margin - row_spacing);
                    // Even though there's enough room, the scrollbar appears, which costs
                    // enough width that there's not enough room.  So shut it off manually.
                    this.sw.set_policy(PolicyType.NEVER, PolicyType.NEVER);
                } else {
                    this.sw.set_size_request(this.max_width, this.max_height);
                    this.sw.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
                }

                var pixbuf = new Pixbuf(Colorspace.RGB, true, 8, this.target_width, this.target_height);
                pixbuf.fill(0x7f7f7fff);
                var iter = TreeIter();
                for (int i=0; i<this.n_slides; i++) {
                    this.slides.append(out iter);
                    this.slides.set_value(iter, 0, pixbuf);
                }
                this.structure_done = true;
            }
            GLib.Idle.add(this.fill_previews);
        }

        /**
         * Fill the previews (only if we have a cache and we are displayed).
         * The size of the icons should be known already
         *
         * This is done in a progressive way (one slide at a time) instead of
         * all the slides in one go to provide some progress feedback to the
         * user.
         */
        protected bool fill_previews() {
            if (this.cache == null || !this.shown || this.next_undone_preview >= this.n_slides)
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
         * Hides the widget
         */
        public override void hide() {
            base.hide();
            this.shown = false;
        }

        /**
         * Gives the cache to retrieve the images from. The caching process
         * itself should already be finished.
         */
        public void set_cache(Renderer.Cache.Base cache) {
            this.cache = cache;
            if (this.shown)
                GLib.Idle.add(this.fill_previews);
        }
        
        /**
         * Set the number of slides. If it is different to what we know, it
         * triggers a rebuilding of the widget.
         */
        public void set_n_slides(int n) {
            if ( n != this.n_slides ) {
                var currently_selected = this.get_current_slide();
                this.invalidate();
                this.n_slides = n;
                if ( this.shown ) {
                    this.fill_structure();
                    if ( currently_selected >= this.n_slides )
                        currently_selected = this.n_slides - 1;
                    this.set_current_slide(currently_selected);
                }
            }
        }

        /**
         * Invalidates the current structure, e.g. because the number of (user)
         * slides changed.
         */
        protected void invalidate() {
            this.slides.clear();
            this.structure_done = false;
            this.next_undone_preview = 0;
        }

        /**
         * Set the current highlighted button (and deselect the previous one)
         */
        public void set_current_slide(int b) {
            var path = new TreePath.from_indices(b);
            this.slides_view.select_path(path);
            this.slides_view.set_cursor(path, null, false);
        }

        /**
         * Which is the current highlighted button/slide?
         */
        public int get_current_slide() {
            return this.current_slide;
        }

        /**
         * We handle some "navigation" key presses ourselves. Others are left to
         * the standard IconView controls, the rest are passed back to the
         * PresentationController.
         */
        public bool on_key_press(Gtk.Widget source, EventKey key) {
            bool handled = false;
            var currently_selected = this.get_current_slide();
            switch ( key.keyval ) {
                case 0xff51: /* Cursor left */
                case 0xff55: /* Page Up */
                    if ( currently_selected > 0)
                        this.set_current_slide( currently_selected - 1 );
                    handled = true;
                    break;
                case 0xff53: /* Cursor right */
                case 0xff56: /* Page down */
                    if ( currently_selected < this.n_slides - 1 )
                        this.set_current_slide( currently_selected + 1 );
                    handled = true;
                    break;
                case 0xff0d: /* Return */
                    this.presentation_controller.goto_user_page(currently_selected + 1);
                    break;
            }
                    
            return handled;
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
                    this.current_slide = tp.get_indices()[0];
                    this.presenter.custom_slide_count(this.current_slide + 1);
                    return;
                }
            }
            // If there's no selection, reset the old one
            this.set_current_slide(this.current_slide);
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
