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
     * Window showing the currently active and next slide.
     *
     * Other useful information like time slide count, ... can be displayed here as
     * well.
     */
    public class Presenter: Fullscreen, Controllable {
        /**
         * Controller handling all the events which might happen. Furthermore it is
         * responsible to update all the needed visual stuff if needed
         */
        protected PresentationController presentation_controller = null;

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
         * Countdown until the presentation ends
         */
        protected TimerLabel timer;

        /**
         * Is the timer paused
         */
        protected bool timer_paused;

        /**
         * Slide progress label ( eg. "23/42" )
         */
        protected Entry slide_progress;

        protected ProgressBar prerender_progress;

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
        protected TextView notes_view;

        /**
         * Layout to position all the elements inside the window
         */
        protected VBox fullLayout = null;

        protected HBox slideViews = null;
        
        protected Overview overview = null;

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
         * Useful colors
         */
        protected Color black;
        protected Color white;

        /**
         * Base constructor instantiating a new presenter window
         */
        public Presenter( Metadata.Pdf metadata, int screen_num, PresentationController presentation_controller ) {
            base( screen_num );

            this.destroy.connect( (source) => {
                Gtk.main_quit();
            } );

            this.presentation_controller = presentation_controller;
            this.presentation_controller.register_controllable( this );
            
            this.metadata = metadata;

            Color.parse( "black", out this.black );
            Color.parse( "white", out this.white );

            this.modify_bg( StateType.NORMAL, this.black );

            // We need the value of 90% height a lot of times. Therefore store it
            // in advance
            var bottom_position = (int)Math.floor( this.screen_geometry.height * 0.9 );
            var bottom_height = this.screen_geometry.height - bottom_position;

            // In most scenarios the current slide is displayed bigger than the
            // next one. The option current_size represents the width this view
            // should use as a percentage value. The maximal height is 90% of
            // the screen, as we need a place to display the timer and slide
            // count.
            Rectangle current_scale_rect;
            int current_allocated_width = (int)Math.floor( 
                this.screen_geometry.width * Options.current_size / (double)100 
            );
            this.current_view = View.Pdf.from_metadata( 
                metadata,
                current_allocated_width,
                bottom_position,
                Options.black_on_end,
                this.presentation_controller,
                out current_scale_rect
            );

            // The next slide is right to the current one and takes up the
            // remaining width
            Rectangle next_scale_rect;
            var next_allocated_width = this.screen_geometry.width - current_allocated_width-4; // We leave a bit of margin between the two views
            this.next_view = View.Pdf.from_metadata( 
                metadata,
                next_allocated_width,
                bottom_position,
                true,
                this.presentation_controller,
                out next_scale_rect
            );

            this.strict_next_view = View.Pdf.from_metadata(
                metadata,
                (int)Math.floor(0.2*current_allocated_width),
                bottom_position,
                true,
                this.presentation_controller,
                out next_scale_rect
            );
            this.strict_prev_view = View.Pdf.from_metadata(
                metadata,
                (int)Math.floor(0.2*current_allocated_width),
                bottom_position,
                true,
                this.presentation_controller,
                out next_scale_rect
            );

            // TextView for notes in the slides
            var notes_font = Pango.FontDescription.from_string( "Verdana" );
            notes_font.set_size( 
                (int)Math.floor( 20 * 0.75 ) * Pango.SCALE
            );
            this.notes_view = new TextView();
            this.notes_view.editable = false;
            this.notes_view.cursor_visible = false;
            this.notes_view.wrap_mode = WrapMode.WORD;
            this.notes_view.modify_font(notes_font); 
            this.notes_view.modify_base(StateType.NORMAL, black);
            this.notes_view.modify_text(StateType.NORMAL, white);
            this.notes_view.buffer.text = "";
            this.notes_view.key_press_event.connect( this.on_key_press_notes_view );

            // Initial font needed for the labels
            // We approximate the point size using pt = px * .75
            var font = Pango.FontDescription.from_string( "Verdana" );
            font.set_size( 
                (int)Math.floor( bottom_height * 0.8 * 0.75 ) * Pango.SCALE
            );

            // Calculate the countdown to display until the presentation has to
            // start
            time_t start_time = 0;
            if ( Options.start_time != null ) 
            {
                start_time = this.parseTime( 
                    Options.start_time 
                );
            }
            // The same again for end_time
            // 
            time_t end_time = 0;
            if ( Options.end_time != null ) 
            {
                end_time = this.parseTime( 
                    Options.end_time 
                );
                Options.duration = 0;
                this.metadata.set_duration(0);
            }

            // The countdown timer is centered in the 90% bottom part of the screen
            // It takes 3/4 of the available width
            this.timer = getTimerLabel( (int)this.metadata.get_duration() * 60, end_time, Options.last_minutes, start_time );
            this.timer.set_justify( Justification.CENTER );
            this.timer.modify_font( font );


            // The slide counter is centered in the 90% bottom part of the screen
            // It takes 1/4 of the available width on the right
            this.slide_progress = new Entry();
            this.slide_progress.set_alignment(1f);
            this.slide_progress.modify_base(StateType.NORMAL, this.black);
            this.slide_progress.modify_text(StateType.NORMAL, this.white);
            this.slide_progress.modify_font( font );
            this.slide_progress.editable = false;
            this.slide_progress.has_frame = false;
            this.slide_progress.key_press_event.connect( this.on_key_press_slide_progress );
            this.slide_progress.inner_border = new Border();
    
            this.prerender_progress = new ProgressBar();
            this.prerender_progress.text = "Prerendering...";
            this.prerender_progress.modify_font( notes_font );
            this.prerender_progress.modify_bg( StateType.NORMAL, this.black );
            this.prerender_progress.modify_bg( StateType.PRELIGHT, this.white );
            this.prerender_progress.modify_fg( StateType.NORMAL, this.white );
            this.prerender_progress.modify_fg( StateType.PRELIGHT, this.black );
            this.prerender_progress.no_show_all = true;

            try {
                int icon_height = bottom_height - 10;

                var blank_pixbuf = Rsvg.pixbuf_from_file_at_size(icon_path + "blank.svg", (int)Math.floor(1.06*icon_height), icon_height);
                this.blank_icon = new Gtk.Image.from_pixbuf(blank_pixbuf);
                this.blank_icon.no_show_all = true;

                var frozen_pixbuf = Rsvg.pixbuf_from_file_at_size(icon_path + "snow.svg", icon_height, icon_height);
                this.frozen_icon = new Gtk.Image.from_pixbuf(frozen_pixbuf);
                this.frozen_icon.no_show_all = true;

                var pause_pixbuf = Rsvg.pixbuf_from_file_at_size(icon_path + "pause.svg", icon_height, icon_height);
                this.pause_icon = new Gtk.Image.from_pixbuf(pause_pixbuf);
                this.pause_icon.no_show_all = true;
            } catch (Error e) {
                error("%s", e.message);
            }

            this.add_events(EventMask.KEY_PRESS_MASK);
            this.add_events(EventMask.BUTTON_PRESS_MASK);
            this.add_events(EventMask.SCROLL_MASK);

            this.key_press_event.connect( this.on_key_pressed );
            this.button_press_event.connect( this.on_button_press );
            this.scroll_event.connect( this.on_scroll );

            // Store the slide count once
            this.slide_count = metadata.get_slide_count();

            this.update();
            this.reset_timer();

            // Enable the render caching if it hasn't been forcefully disabled.
            if ( !Options.disable_caching ) {               
                ((Renderer.Caching)this.current_view.get_renderer()).set_cache( 
                    Renderer.Cache.OptionFactory.create( 
                        metadata
                    )
                );
                ((Renderer.Caching)this.next_view.get_renderer()).set_cache( 
                    Renderer.Cache.OptionFactory.create( 
                        metadata
                    )
                );
                ((Renderer.Caching)this.strict_next_view.get_renderer()).set_cache( 
                    Renderer.Cache.OptionFactory.create( 
                        metadata
                    )
                );
                ((Renderer.Caching)this.strict_prev_view.get_renderer()).set_cache( 
                    Renderer.Cache.OptionFactory.create( 
                        metadata
                    )
                );
            }

            this.build_layout();
        }

        public override void show() {
            base.show();
            this.overview.setMaxWidth(this.slideViews.allocation.width);
        }

        protected void build_layout() {
            this.slideViews = new HBox(false, 4);

            var strict_views = new HBox(false, 0);
            strict_views.pack_start(this.strict_prev_view, false, false, 0);
            strict_views.pack_end(this.strict_next_view, false, false, 0);

            var current_view_and_stricts = new VBox(false, 2);
            current_view_and_stricts.pack_start(this.current_view, false, false, 2);
            current_view_and_stricts.pack_start(strict_views, false, false, 2);

            //var center_current_view = new Alignment(0, (float)0.5, 0, 0);
            //center_current_view.add(this.current_view);
            this.slideViews.add( current_view_and_stricts );

            var nextViewWithNotes = new VBox(false, 0);
            nextViewWithNotes.pack_start( this.next_view, false, false, 0 );
            nextViewWithNotes.pack_start( this.notes_view, true, true, 5 );
            this.slideViews.add(nextViewWithNotes);

            var bottomRow = new HBox(true, 0);

            var status = new HBox(false, 2);
            //blank_label_alignment.add( this.blank_label );
            status.pack_start( this.blank_icon, false, false, 0 );
            status.pack_start( this.frozen_icon, false, false, 0 );
            status.pack_start( this.pause_icon, false, false, 0 );

            var timer_alignment = new Alignment(0.5f, 0.5f, 0, 0);
            timer_alignment.add( this.timer );

            var progress_alignment = new HBox(false, 0);
            progress_alignment.pack_end(this.slide_progress);
            var prerender_alignment = new Alignment(0, 0.5f, 1, 0);
            prerender_alignment.add(this.prerender_progress);
            progress_alignment.pack_start(prerender_alignment);

            bottomRow.pack_start( status, true, true, 0);
            bottomRow.pack_start( timer_alignment, true, true, 0 );
            bottomRow.pack_end( progress_alignment, true, true, 0);

            //var fullLayout = new VBox(false, 0);
            this.fullLayout = new VBox(false, 0);
            fullLayout.pack_start( this.slideViews, true, true, 0 );
            fullLayout.pack_end( bottomRow, false, false, 0 );
            
            this.add( fullLayout );

            this.overview = new Overview( this.metadata, this.presentation_controller, this );
            this.overview.no_show_all = true;
            this.overview.set_n_slides( this.presentation_controller.get_user_n_slides() );
            this.fullLayout.pack_start( this.overview, true, true, 0 );
            this.presentation_controller.set_overview(this.overview);
        }

        /**
         * Handle keypress events on the window and, if neccessary send them to the
         * presentation controller
         */
        protected bool on_key_pressed( Gtk.Widget source, EventKey key ) {
            if ( this.presentation_controller != null ) {
                return this.presentation_controller.key_press( key );
            } else {
                // Can this happen?
                return false;
            }
        }

        /**
         * Handle mouse button events on the window and, if neccessary send
         * them to the presentation controller
         */
        protected bool on_button_press( Gtk.Widget source, EventButton button ) {
            if ( this.presentation_controller != null ) {
                this.presentation_controller.button_press( button );
            }
            return false;
        }

        /**
         * Handle mouse scrolling events on the window and, if neccessary send
         * them to the presentation controller
         */
        protected bool on_scroll( Gtk.Widget source, EventScroll scroll ) {
            if ( this.presentation_controller != null ) {
                this.presentation_controller.scroll( scroll );
            }
            return false;
        }

        /**
         * Update the slide count view
         */
        protected void update_slide_count() {
            this.custom_slide_count(
                    this.presentation_controller.get_current_user_slide_number() + 1, 
                    this.presentation_controller.get_end_user_slide()
            );
        }

        public void custom_slide_count(int current, int total) {
            this.slide_progress.set_text( "%d/%u".printf(current, total) );
        }

        /**
         * Return the registered PresentationController
         */
        public PresentationController? get_controller() {
            return this.presentation_controller;
        }

        public void update() {
            if (this.overview != null) {
                this.overview.hide();
                this.slideViews.show();
            }
            int current_slide_number = this.presentation_controller.get_current_slide_number();
            int current_user_slide_number = this.presentation_controller.get_current_user_slide_number();
            try {
                this.current_view.display(current_slide_number);
                this.next_view.display(this.metadata.user_slide_to_real_slide(current_user_slide_number + 1));
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
                GLib.error( "The pdf page %d could not be rendered: %s", current_slide_number, e.message );
            }
            this.update_slide_count();
            this.update_note();
            if (!this.timer_paused)
                this.timer.start();
            if (this.presentation_controller.is_faded_to_black())
                this.blank_icon.show();
            else
                this.blank_icon.hide();
            if (this.presentation_controller.is_frozen())
                this.frozen_icon.show();
            else
                this.frozen_icon.hide();
            this.faded_to_black = false;
        }

        /**
         * Display a specific page
         */
        public void goto_page( int page_number ) {
            try {
                this.current_view.display( page_number );
                this.next_view.display( 
                    page_number + 1
                );
            }
            catch( Renderer.RenderError e ) {
                GLib.error( "The pdf page %d could not be rendered: %s", page_number, e.message );
            }

            this.update_slide_count();
            this.update_note();
            this.blank_icon.hide();
            if (!this.timer_paused)
                this.timer.start();
        }

        /**
         * Ask for the page to jump to
         */
        public void ask_goto_page() {
           this.slide_progress.set_text("/%u".printf(this.presentation_controller.get_user_n_slides()));
           this.slide_progress.modify_cursor(white, null);
           this.slide_progress.editable = true;
           this.slide_progress.grab_focus();
           this.slide_progress.set_position(0);
           this.presentation_controller.set_ignore_input_events( true );
        }

        /**
         * Handle key events for the slide_progress entry field
         */
        protected bool on_key_press_slide_progress( Gtk.Widget source, EventKey key ) {
            if ( key.keyval == 0xff0d ) {
                // Try to parse the input
               string input_text = this.slide_progress.text;
               int destination = int.parse(input_text.substring(0, input_text.index_of("/")));
               this.slide_progress.modify_cursor(black, null);
               this.slide_progress.editable = false;
               this.presentation_controller.set_ignore_input_events( false );
               if ( destination != 0 )
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
            this.presentation_controller.set_ignore_input_events( true );
        }

        /**
         * Handle key presses when editing a note
         */
        protected bool on_key_press_notes_view( Gtk.Widget source, EventKey key ) {
            if ( key.keyval == 0xff1b) { /* Escape */
                this.notes_view.editable = false;
                this.notes_view.cursor_visible = false;
                this.metadata.get_notes().set_note( this.notes_view.buffer.text, this.presentation_controller.get_current_user_slide_number() );
                this.presentation_controller.set_ignore_input_events( false );
                return true;
            } else {
                return false;
            }
        }
        
        /**
         * Update the text of the current note
         */
        protected void update_note() {
            string this_note = this.metadata.get_notes().get_note_for_slide(this.presentation_controller.get_current_user_slide_number());
            this.notes_view.buffer.text = this_note;
        }

        public void show_overview() {
            this.slideViews.hide();
            this.overview.show();
            this.overview.set_current_button(this.presentation_controller.get_current_user_slide_number());
        }

        public void hide_overview() {
            this.overview.hide();
            this.slideViews.show();
        }

        /** 
         * Take a cache observer and register it with all prerendering Views
         * shown on the window.
         *
         * Furthermore it is taken care of to add the cache observer to this window
         * for display, as it is a Image widget after all.
         */
        public void set_cache_observer( CacheStatus observer ) {
            var current_prerendering_view = this.current_view as View.Prerendering;
            if( current_prerendering_view != null ) {
                observer.monitor_view( current_prerendering_view );
            }
            var next_prerendering_view = this.next_view as View.Prerendering;
            if( next_prerendering_view != null ) {
                observer.monitor_view( next_prerendering_view );
            }
            
            //observer.register_entry( this.slide_progress );
            //observer.register_update( this.prerender_progress.set_fraction, () => this.prerender_progress.hide() );
            observer.register_update( this.prerender_progress.set_fraction, this.prerender_finished );
            this.prerender_progress.show();
        }

        public void prerender_finished() {
            this.prerender_progress.hide();
            this.overview.set_cache(((Renderer.Caching)this.next_view.get_renderer()).get_cache());
        }
    
        /**
         * Parse the given time string to a Time object
         */
        private time_t parseTime( string t ) 
        {
            var tm = Time.local( time_t() );
            tm.strptime( t + ":00", "%H:%M:%S" );
            return tm.mktime();
        }

        /**
         * Pause the presentation
         */
        public void toggle_pause() {
            this.timer_paused = this.timer.pause();
            if ( this.timer_paused )
                this.pause_icon.show();
            else
                this.pause_icon.hide();
        }

        /**
         * Pause the presentation
         */
        public void reset_timer() {
            this.timer.reset();
            this.timer_paused = false;
            this.pause_icon.hide();
        }
    }

}
