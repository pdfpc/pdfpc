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
         * Countdown until the presentation ends
         */
        protected TimerLabel timer;

        /**
         * Slide progress label ( eg. "23/42" )
         */
        protected Entry slide_progress;

        /**
         * Indication that the slide is blanked (faded to black)
         */
        protected Label blank_label;

        /**
         * Text box for displaying notes for the slides
         */
        protected TextView notes_view;

        /**
         * Layout to position all the elements inside the window
         */
        protected VBox fullLayout = null;

        /**
         * Number of slides inside the presentation
         *
         * This value is needed a lot of times therefore it is retrieved once
         * and stored here for performance and readability reasons.
         */
        protected uint slide_count;

        /**
         * Notes for the slides
         */
        protected SlidesNotes notes;

        /**
         * Useful colors
         */
        protected Color black;
        protected Color white;

        /**
         * Base constructor instantiating a new presenter window
         */
        public Presenter( string pdf_filename, int screen_num, SlidesNotes slides_notes ) {
            base( screen_num );

            this.destroy.connect( (source) => {
                Gtk.main_quit();
            } );

            Color.parse( "black", out this.black );
            Color.parse( "white", out white );

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
            this.current_view = View.Pdf.from_pdf_file( 
                pdf_filename,
                current_allocated_width,
                0,
                //bottom_position,
                Options.black_on_end,
                out current_scale_rect
            );
            this.notes = slides_notes;

            // The next slide is right to the current one and takes up the
            // remaining width
            Rectangle next_scale_rect;
            var next_allocated_width = this.screen_geometry.width - current_allocated_width-4; // We leave a bit of margin between the two views
            this.next_view = View.Pdf.from_pdf_file( 
                pdf_filename,
                next_allocated_width,
                0,
                //bottom_position,
                true,
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
                start_time = this.parseStartTime( 
                    Options.start_time 
                );
            }

            // The countdown timer is centered in the 90% bottom part of the screen
            // It takes 3/4 of the available width
            this.timer = new TimerLabel( (int)Options.duration * 60, start_time );
            this.timer.set_justify( Justification.CENTER );
            this.timer.modify_font( font );
            this.timer.set_last_minutes( Options.last_minutes );


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

            this.blank_label = new Label( "Blank" );
            this.blank_label.set_justify( Justification.LEFT );
            this.blank_label.modify_fg( StateType.NORMAL, this.white );
            this.blank_label.modify_font( font );
            this.blank_label.no_show_all = true;

            this.add_events(EventMask.KEY_PRESS_MASK);
            this.add_events(EventMask.BUTTON_PRESS_MASK);

            this.key_press_event.connect( this.on_key_pressed );
            this.button_press_event.connect( this.on_button_press );

            // Store the slide count once
            this.slide_count = this.current_view.get_renderer().get_metadata().get_slide_count();

            this.reset();

            // Enable the render caching if it hasn't been forcefully disabled.
            if ( !Options.disable_caching ) {               
                ((Renderer.Caching)this.current_view.get_renderer()).set_cache( 
                    Renderer.Cache.OptionFactory.create( 
                        this.current_view.get_renderer().get_metadata()
                    )
                );
                ((Renderer.Caching)this.next_view.get_renderer()).set_cache( 
                    Renderer.Cache.OptionFactory.create( 
                        this.next_view.get_renderer().get_metadata()
                    )
                );
            }

            this.build_layout();
        }

        protected void build_layout() {
            var slideViews = new HBox(false, 4);
            var center_current_view = new Alignment(0, (float)0.5, 0, 0);
            center_current_view.add(this.current_view);
            slideViews.add( center_current_view );

            var nextViewWithNotes = new VBox(false, 0);
            nextViewWithNotes.pack_start( this.next_view, false, false, 0 );
            nextViewWithNotes.pack_start( this.notes_view, true, true, 5 );
            slideViews.add(nextViewWithNotes);

            var bottomRow = new HBox(true, 0);
            var blank_label_alignment = new Alignment(0, 0.5f, 0, 0);
            var timer_alignment = new Alignment(0.5f, 0.5f, 0, 0);
            var slide_progress_alignment = new Alignment(1, 0.5f, 1, 0);
            blank_label_alignment.add( this.blank_label );
            timer_alignment.add( this.timer );
            slide_progress_alignment.add( this.slide_progress );
            bottomRow.pack_start( blank_label_alignment, true, true, 0);
            bottomRow.pack_start( timer_alignment, true, true, 0 );
            bottomRow.pack_end( slide_progress_alignment, true, true, 0);

            //var fullLayout = new VBox(false, 0);
            this.fullLayout = new VBox(false, 0);
            fullLayout.pack_start( slideViews );
            fullLayout.pack_start( bottomRow );
            
            this.add( fullLayout );
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
         * Update the slide count view
         */
        protected void update_slide_count() {
            this.slide_progress.set_text( 
                "%d/%u".printf( 
                    this.presentation_controller.get_current_user_slide_number() + 1, 
                    this.presentation_controller.get_user_n_slides()
                )        
            );
        }

        /**
         * Set the presentation controller which is notified of keypresses and
         * other observed events
         */
        public void set_controller( PresentationController controller ) {
            this.presentation_controller = controller;
        }

        /**
         * Return the registered PresentationController
         */
        public PresentationController? get_controller() {
            return this.presentation_controller;
        }

        public void update() {
            int current_slide_number = this.presentation_controller.get_current_slide_number();
            try {
                this.current_view.display(current_slide_number);
                this.next_view.display(current_slide_number + 1);
            }
            catch( Renderer.RenderError e ) {
                GLib.error( "The pdf page %d could not be rendered: %s", current_slide_number, e.message );
            }
            this.update_slide_count();
            this.update_note();
            this.timer.start();
            this.blank_label.hide();
            this.faded_to_black = false;
        }

        /**
         * Reset the presentation display to the initial status
         */
        public void reset() {
            this.timer.reset();
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
            this.blank_label.hide();
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
               return true;
            } else {
               return false;
            }
        }

        /**
         * We will notify the presenter that the screen is faded to black, but
         * we will retain the slide view.
         */
        public void fade_to_black() {
            if (this.faded_to_black)
                this.blank_label.hide();
            else
                this.blank_label.show();
            this.faded_to_black = !this.faded_to_black;
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
                this.notes.set_note( this.notes_view.buffer.text, this.presentation_controller.get_current_user_slide_number() );
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
            string this_note = notes.get_note_for_slide(this.presentation_controller.get_current_user_slide_number());
            this.notes_view.buffer.text = this_note;
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

            // Add the cache status widget to be displayed
            observer.set_height( 6 );
            observer.set_width( this.screen_geometry.width );
            //this.fixedLayout.put( 
            //    observer,
            //    0,
            //    this.screen_geometry.height - 6 
            //);
            this.fullLayout.pack_end( observer, false, false, 0 );
            observer.show();
        }

        /**
         * Parse the given start time string to a Time object
         */
        private time_t parseStartTime( string start_time ) 
        {
            var tm = Time.local( time_t() );
            tm.strptime( start_time, "%H:%M:%S" );
            return tm.mktime();
        }
    }
}
