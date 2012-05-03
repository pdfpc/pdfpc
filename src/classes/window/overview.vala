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
    public class Overview: Gtk.ScrolledWindow {
        /**
         * The underlying table
         */
        private Gtk.Table table;

        /**
         * Each slide is represented via a derived class of Gtk.Button (see
         * below). We keep references here (as well as implicitely in the
         * Gtk.Table to more convenient referencing.
         */
        private OverviewButton[] button;

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
         * The dimension of the table (square)
         */
        protected int xdimension = 0;
    
        /**
         * The height and width allocated for each button. Needed for scaling
         * the images.
         */
        protected int buttonWidth;
        protected int buttonHeight;

        /**
         * The height and width of the pixmaps provided by the cache
         */
        protected int pixmapWidth;
        protected int pixmapHeight;

        /**
         * The target height and width of the scaled images, a bit smaller than
         * the button dimensions to allow some margin
         */
        protected int targetWidth;
        protected int targetHeight;

        /**
         * Currently selected button/user slide
         */
        protected int currently_selected = 0;

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

        double aspectRatio;

        int maxXDimension;

        /**
         * Constructor
         */
        public Overview( Metadata.Pdf metadata, PresentationController presentation_controller, Presenter presenter ) {

            this.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            this.table = new Gtk.Table(0, 0, false);
            var tableViewport = new Gtk.Viewport(null, null);
            tableViewport.add(this.table);
            this.add(tableViewport);

            this.table.show();
            tableViewport.show();

            Color black;
            Color white;
            Color.parse("black", out black);
            Color.parse("white", out white);
            //this.table.modify_bg(StateType.NORMAL, black);
            //this.table.modify_bg(StateType.ACTIVE, black);
            tableViewport.modify_bg(StateType.NORMAL, black);
            //this.modify_bg(StateType.NORMAL, black);
            Gtk.Scrollbar vscrollbar = (Gtk.Scrollbar) this.get_vscrollbar();
            //this.scrolledWindow.set_shadow_type(Gtk.ShadowType.NONE);
            vscrollbar.modify_bg(StateType.NORMAL, white);
            vscrollbar.modify_bg(StateType.ACTIVE, black);
            vscrollbar.modify_bg(StateType.PRELIGHT, white);
            //this.scrolledWindow.get_vscrollbar().modify_fg(StateType.NORMAL, black);
            

            this.metadata = metadata;
            this.presentation_controller = presentation_controller;
            this.presenter = presenter;

            this.add_events(EventMask.KEY_PRESS_MASK);
            this.key_press_event.connect( this.on_key_press );

            this.aspectRatio = this.metadata.get_page_width() / this.metadata.get_page_height();
        }

        public void setMaxWidth(int width) {
            this.maxXDimension = (int)Math.floor((width - 20) / Options.min_overview_width);;
        }

        /**
         * We handle the "navigation" key presses ourselves. The rest is left
         * to the presentation_controller, as in normal mode.
         */
        public bool on_key_press(Gtk.Widget source, EventKey key) {
            bool handled = false;
            switch ( key.keyval ) {
                case 0xff53: /* Cursor right */
                    if ( this.currently_selected % this.xdimension != this.xdimension-1 &&
                         this.currently_selected < this.n_slides - 1 )
                        this.set_current_button( this.currently_selected + 1 );
                    handled = true;
                    break;
                case 0xff51: /* Cursor left */
                    if ( this.currently_selected % this.xdimension != 0 )
                        this.set_current_button( this.currently_selected - 1 );
                    handled = true;
                    break;
                case 0xff55: /* Page Up */
                    if ( this.currently_selected > 0)
                        this.set_current_button( this.currently_selected - 1 );
                    handled = true;
                    break;
                case 0xff56: /* Page down */
                    if ( this.currently_selected < this.n_slides - 1 )
                        this.set_current_button( this.currently_selected + 1 );
                    handled = true;
                    break;
                case 0xff52: /* Cursor up */
                    if ( this.currently_selected >= this.xdimension )
                        this.set_current_button( this.currently_selected - this.xdimension );
                    handled = true;
                    break;
                case 0xff54: /* Cursor down */
                    if ( this.currently_selected <= this.n_slides - 1 - this.xdimension )
                        this.set_current_button( this.currently_selected + this.xdimension );
                    handled = true;
                    break;
                case 0xff50: /* Home */
                    this.set_current_button( 0 );
                    handled = true;
                    break;
                case 0xff57: /* End */
                    this.set_current_button( this.n_slides - 1 );
                    handled = true;
                    break;
                case 0xff0d: /* Return */
                    this.presentation_controller.goto_user_page(this.currently_selected + 1);
                    break;
            }
                    
            return handled;
        }

        /**
         * Show the widget + build the structure if needed
         */
        public override void show() {
            base.show();
            this.shown = true;
            this.fill_structure();
        }

        /**
         * Fill the widget with buttons.
         *
         * Note: gtk uses a "lazy" policy for creating widgets. What this means
         * for us is that we will not know the final size of the buttons in
         * this function, and thus the miniatures must be built in a separate
         * function.
         */
        protected void fill_structure() {
            if (!this.structure_done) {
                this.xdimension = (int)Math.ceil(Math.sqrt(this.n_slides));
                int ydimension;
                if (this.xdimension > this.maxXDimension) {
                    this.xdimension = this.maxXDimension;
                    ydimension = (int)Math.ceil(this.n_slides/this.xdimension);
                } else {
                    ydimension = this.xdimension;
                }
                this.table.resize(this.xdimension, ydimension);
                int currentButton = 0;
                int r = 0;
                while (currentButton < this.n_slides) {
                    for (int c = 0; currentButton < this.n_slides && c < this.xdimension; ++c) {
                        var newButton = new OverviewButton(currentButton, this.aspectRatio, this, this.presentation_controller);
                        newButton.show();
                        this.table.attach_defaults(newButton, c, c+1, r, r+1);
                        this.button += newButton;
                        ++currentButton;
                    }
                    ++r;
                }
                this.structure_done = true;
            }
            GLib.Idle.add(this.idle_get_button_size_and_queue_fill_previews);
        }

        /**
         * This function will be called when idle, i.e. the buttons will
         * already have been created and we can know their size. Then it queues
         * the preview building.
         */
        public bool idle_get_button_size_and_queue_fill_previews() {
            if (this.cache != null) {
                this.buttonWidth = this.button[0].allocation.width;
                this.buttonHeight = this.button[0].allocation.height;
                this.cache.retrieve(0).get_size(out pixmapWidth, out pixmapHeight);
                Scaler scaler = new Scaler(pixmapWidth, pixmapHeight);
                Rectangle rect = scaler.scale_to(this.buttonWidth-10, this.buttonHeight-10);
                this.targetWidth = rect.width;
                this.targetHeight = rect.height;

                GLib.Idle.add(this.fill_previews);
            }
            return false;
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
                GLib.Idle.add(this.idle_get_button_size_and_queue_fill_previews);
        }
        
        /**
         * Set the number of slides. If it is different to what we know, it
         * triggers a rebuilding of the widget.
         */
        public void set_n_slides(int n) {
            if ( n != this.n_slides ) {
                this.invalidate();
                this.n_slides = n;
                if ( this.shown ) {
                    this.fill_structure();
                    if ( this.currently_selected >= this.n_slides )
                        this.currently_selected = this.n_slides - 1;
                    this.set_current_button(this.currently_selected);
                }
            }
        }

        /**
         * Invalidates the current structure, e.g. because the number of (user)
         * slides changed.
         */
        protected void invalidate() {
            for (int b = 0; b < button.length; ++b)
                this.table.remove(button[b]);
            button.resize(0);
            this.structure_done = false;
            this.next_undone_preview = 0;
        }

        /**
         * Fill the previews (only if we have a cache and we are displayed).
         * The size of the buttons should be known already
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

            var thisButton = button[this.next_undone_preview];
            var pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB, true, 8, this.pixmapWidth, this.pixmapHeight);
            Gdk.pixbuf_get_from_drawable(pixbuf, this.cache.retrieve(metadata.user_slide_to_real_slide(this.next_undone_preview)), null, 0, 0, 0, 0, this.pixmapWidth, this.pixmapHeight);
            var image = new Gtk.Image.from_pixbuf(pixbuf.scale_simple(this.targetWidth, this.targetHeight, Gdk.InterpType.BILINEAR));
            thisButton.set_label("");
            thisButton.set_image(image);

            ++this.next_undone_preview;

            if (this.next_undone_preview < this.n_slides)
                return true;
            else
                return false;
        }

        /**
         * Set the current highlighted button (and deselect the previous one)
         */
        public void set_current_button(int b) {
            button[this.currently_selected].unset_current();
            button[b].set_current();
            this.currently_selected = b;
            this.presenter.custom_slide_count(this.currently_selected+1, (int)this.n_slides);
        }

        /**
         * Which is the current highlighted button/slide?
         */
        public int get_current_button() {
            return this.currently_selected;
        }
    }

    /**
     * A derived class of Gtk.Button with custom colors and clicked action
     */
    public class OverviewButton : Gtk.Button {
        /**
         * Colors and font
         */
        protected static Color? black = null;
        protected static Color? white = null;
        protected static Color? yellow = null;
        protected static Pango.FontDescription? font = null;

        /**
         * Which slide we refer to
         */
        protected int id;

        /**
         * Constructor: set the id, the formatting and the clicked action
         */
        public OverviewButton(int id, double aspectRatio, Overview overview, PresentationController presentation_controller) {
            this.id = id;

            if ( this.black == null ) {
                Color.parse( "black", out this.black );
                Color.parse( "white", out this.white );
                Color.parse( "yellow", out this.yellow );
                font = Pango.FontDescription.from_string( "Verdana" );
                font.set_size( 20 * Pango.SCALE );
            }

            this.set_label("%d".printf(this.id + 1));
            var buttonLabel = this.get_children().nth_data(0);
            buttonLabel.modify_font(font);
            buttonLabel.modify_fg(StateType.NORMAL, this.white);
            buttonLabel.modify_fg(StateType.PRELIGHT, this.white);
            this.modify_bg(StateType.NORMAL, this.black);
            this.modify_bg(StateType.PRELIGHT, this.black);
            this.modify_bg(StateType.ACTIVE, this.black);

            // Set a minumum size for the button
            this.set_size_request(Options.min_overview_width, (int)Math.round(Options.min_overview_width/aspectRatio));

            this.enter.connect(() => overview.set_current_button(id));
            this.clicked.connect(() => presentation_controller.goto_user_page(this.id + 1));
        } 

        /**
         * Hilight the button
         */
        public void set_current() {
            this.modify_bg(StateType.NORMAL, this.yellow);
            this.modify_bg(StateType.PRELIGHT, this.yellow);
        }

        /**
         * Unselect the button
         */
        public void unset_current() {
            this.modify_bg(StateType.NORMAL, this.black);
            this.modify_bg(StateType.PRELIGHT, this.black);
        }
    }
}
