/**
 * Presentation Event controller
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

using GLib;

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Controller handling all the triggered events/signals
     */
    public class PresentationController: Object {

        /**
         * The currently displayed slide
         */
        protected int current_slide_number;

        /**
         * The current slide in "user indexes"
         */
        protected int current_user_slide_number;

        /**
         * Stores if the view is faded to black
         */
        protected bool faded_to_black = false;

        /**
         * Stores if the view is frozen
         */
        protected bool frozen = false;


        /**
         * A flag signaling if we allow for a black slide at the end. Tis is
         * useful for the next view and (for some presenters) also for the main
         * view.
         */
        protected bool black_on_end;

        /**
         * The number of slides in the presentation
         */
        protected int n_slides;

        /**
         * Controllables which are registered with this presentation controller.
         */
        protected List<Controllable> controllables;

        /**
         * Ignore input events. Useful e.g. for editing notes.
         */
        protected bool ignore_keyboard_events = false;
        protected bool ignore_mouse_events = false;

        /**
         * The metadata of the presentation
         */
        protected Metadata.Pdf metadata;

        /**
         * The presenters overview. We need to communicate with it for toggling
         * skips
         */
        protected Window.Overview overview;

        /**
         * Disables processing of multiple Keypresses at the same time (debounce)
         */
        protected uint last_key_event = 0;

        /**
         * Stores the "history" of the slides (jumps only)
         */
        private int[] history;

        /**
         * Instantiate a new controller
         */
        public PresentationController( Metadata.Pdf metadata, bool allow_black_on_end ) {
            this.controllables = new List<Controllable>();

            this.metadata = metadata;

            this.n_slides = (int)metadata.get_slide_count();
            this.black_on_end = allow_black_on_end;
            
            this.current_slide_number = 0;
            this.current_user_slide_number = 0;
        }

        public void set_overview(Window.Overview o) {
            this.overview = o;
        }

        /**
         * Handle keypresses to each of the controllables
         *
         * This seperate handling is needed because keypresses from any of the
         * window have implications on the behaviour of both of them. Therefore
         * this controller is needed to take care of the needed actions.
         *
         * There are no Vala bindings for gdk/gdkkeysyms.h
         * https://bugzilla.gnome.org/show_bug.cgi?id=551184
         *
         */
        enum KeyMappings {
            Normal,
            Overview
        }

        KeyMappings current_key_mapping = KeyMappings.Normal;

        public bool key_press( Gdk.EventKey key ) {
            if(key.time != last_key_event) {
                last_key_event = key.time;
                switch (current_key_mapping) {
                    case KeyMappings.Normal:
                     return key_press_normal(key);
                   case KeyMappings.Overview:
                     return key_press_overview(key);
                }
            }
            return true;
        }

        protected bool key_press_normal( Gdk.EventKey key ) {
            if ( !ignore_keyboard_events ) {
                switch( key.keyval ) {
                    case 0xff0d: /* Return */
                    case 0x1008ff17: /* AudioNext */
                    case 0xff53: /* Cursor right */
                    case 0xff56: /* Page down */
                    case 0x020:  /* Space */
                        if ( (key.state & Gdk.ModifierType.SHIFT_MASK) != 0 )
                            this.jump10();
                        else
                            this.next_page();
                    break;
                    case 0xff54: /* Cursor down */
                        this.next_user_page();
                    break;
                    case 0xff51: /* Cursor left */
                    case 0x1008ff16: /* AudioPrev */
                    case 0xff55: /* Page Up */
                        if ( (key.state & Gdk.ModifierType.SHIFT_MASK) != 0 )
                            this.back10();
                        else
                            this.previous_page();
                    break;
                    case 0xff52: /* Cursor up */
                        this.previous_user_page();
                    break;
                    case 0xff1b: /* Escape */
                    case 0x071:  /* q */
                        this.metadata.save_to_disk();
                        Gtk.main_quit();
                    break;
                    case 0x072: /* r */
                        this.controllables_reset();
                    break;
                    case 0xff50: /* Home */
                        this.goto_first();
                    break;
                    case 0xff57: /* End */
                        this.goto_last();
                    break;
                    case 0x062: /* b */
                        this.fade_to_black();
                    break;
                    case 0x06e: /* n */
                        this.controllables_edit_note();
                    break;
                    case 0x067: /* g */
                        this.controllables_ask_goto_page();
                    break;
                    case 0x066: /* f */
                        this.toggle_freeze();
                    break;
                    case 0x06f: /* o */
                        this.toggle_skip();
                    break;
                    case 0x073: /* s */
                        this.start();
                    break;
                    case 0x070: /* p */
                    case 0xff13: /* pause */
                        this.toggle_pause();
                    break;
                    case 0x065: /* e */
                        this.set_end_user_slide();
                    break;
                    case 0xff09:
                        this.controllables_show_overview();
                    break;
                    case 0xff08:
                        this.history_back();
                    break;
                }
                return true;
            } else {
                return false;
            }
        }

        /**
         * Handle key presses when in overview mode
         *
         * This is a subset of the keybindings above
         */
        protected bool key_press_overview( Gdk.EventKey key ) {
            bool handled = false;
            switch( key.keyval ) {
                case 0xff1b: /* Escape */
                case 0x071:  /* q */
                    this.metadata.save_to_disk();
                    Gtk.main_quit();
                    handled = true;
                break;
                case 0x072: /* r */
                    this.controllables_reset();
                    handled = true;
                break;
                case 0x062: /* b */
                    this.fade_to_black();
                    handled = true;
                break;
                case 0x067: /* g */
                    this.controllables_ask_goto_page();
                    handled = true;
                break;
                case 0x066: /* f */
                    this.toggle_freeze();
                    handled = true;
                break;
                case 0x06f: /* o */
                    this.toggle_skip_overview();
                    handled = true;
                break;
                case 0x073: /* s */
                    this.start();
                    handled = true;
                break;
                case 0x070: /* p */
                case 0xff13: /* pause */
                    this.toggle_pause();
                    handled = true;
                break;
                case 0x065: /* e */
                    this.set_end_user_slide_overview();
                    handled = true;
                break;
                case 0xff09:
                    this.controllables_hide_overview();
                    handled = true;
                break;
            }
            return handled;
        }

        /**
         * Handle mouse clicks to each of the controllables
         */
        public bool button_press( Gdk.EventButton button ) {
            if ( !ignore_mouse_events && button.type ==
                    Gdk.EventType.BUTTON_PRESS ) {
                // Prevent double or triple clicks from triggering additional
                // click events
                switch( button.button ) {
                    case 1: /* Left button */
                        if ( (button.state & Gdk.ModifierType.SHIFT_MASK) != 0 )
                            this.jump10();
                        else
                            this.next_page();
                    break;
                    case 3: /* Right button */
                        if ( (button.state & Gdk.ModifierType.SHIFT_MASK) != 0 )
                            this.back10();
                        else
                            this.previous_page();
                    break;
                }
                return true;
            } else {
                return false;
            }
        }

        /**
         * Notify each of the controllables of mouse scrolling
         */
        public void scroll( Gdk.EventScroll scroll ) {
            if ( !this.ignore_mouse_events ) {
                switch( scroll.direction ) {
                    case Gdk.ScrollDirection.UP: /* Scroll up */
                    case Gdk.ScrollDirection.LEFT: /* Scroll left */ 
                        if ( (scroll.state & Gdk.ModifierType.SHIFT_MASK) != 0 )
                            this.back10();
                        else
                            this.previous_page();
                    break;
                    case Gdk.ScrollDirection.DOWN: /* Scroll down */
                    case Gdk.ScrollDirection.RIGHT: /* Scroll right */ 
                        if ( (scroll.state & Gdk.ModifierType.SHIFT_MASK) != 0 )
                            this.jump10();
                        else
                            this.next_page();
                    break;
                }
            }
        }
        
        /**
         * Get the current (real) slide number
         */
        public int get_current_slide_number() {
            return current_slide_number;
        }

        /**
         * Get the current (user) slide number
         */
        public int get_current_user_slide_number() {
            return current_user_slide_number;
        }
    
        /**
         * Was the previous slide a skip one?
         */
        public bool skip_previous() {
            return this.current_slide_number > this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
        }

        /**
         * Is the next slide a skip one?
         */
        public bool skip_next() {
            return (this.current_user_slide_number >= this.metadata.get_user_slide_count() - 1
                    &&
                    this.current_slide_number < this.n_slides)
                   ||
                   (this.current_slide_number+1 < this.metadata.user_slide_to_real_slide(this.current_user_slide_number+1));
        }

        /**
         * Get the real total number of slides
         */
        public int get_n_slide() {
            return this.n_slides;
        }

        /**
         * Get the user total number of slides
         */
        public int get_user_n_slides() {
            return this.metadata.get_user_slide_count();;
        }

        /**
         * Get the last slide as defined by the user
         */
        public int get_end_user_slide() {
            return this.metadata.get_end_user_slide();
        }
    
        /**
         * Set the last slide as defined by the user
         */
        public void set_end_user_slide() {
            this.metadata.set_end_user_slide(this.current_user_slide_number + 1);
            this.controllables_update();
        }

        /**
         * Set the last slide as defined by the user
         */
        public void set_end_user_slide_overview() {
            int user_selected = this.overview.get_current_button();
            this.metadata.set_end_user_slide(user_selected + 1);
        }

        /**
         * Register the current slide in the history
         */
        void slide2history() {
            this.history += this.current_slide_number;
        }

        /**
         * A request to change the page has been issued
         */
        public void page_change_request( int page_number ) {
            if (page_number != this.current_slide_number)
                this.slide2history();
            this.current_slide_number = page_number;
            this.current_user_slide_number = this.metadata.real_slide_to_user_slide(this.current_slide_number);
            this.controllables_update();
        }

        /**
         * Set the state of ignote_input_events
         */
        public void set_ignore_input_events( bool v ) {
            this.ignore_keyboard_events = v;
            this.ignore_mouse_events = v;
        }

        public void set_ignore_mouse_events( bool v ) {
            this.ignore_mouse_events = v;
        }

        /**
         * Register a new Controllable instance on this controller. 
         *
         * On success true is returned, in case the controllable has already been
         * registered false is returned.
         */
        public bool register_controllable( Controllable controllable ) {
            if ( this.controllables.find( controllable ) != null ) {
                // The controllable has already been added.
                return false;
            }

            //controllable.set_controller( this );
            this.controllables.append( controllable );
            
            return true;
        }

        /**
         * Go to the next slide
         */
        public void next_page() {
            if ( this.current_slide_number < this.n_slides - 1 ) {
                ++this.current_slide_number;
                if (this.current_slide_number == this.metadata.user_slide_to_real_slide(this.current_user_slide_number + 1))
                    ++this.current_user_slide_number;
                if (!this.frozen)
                    this.faded_to_black = false;
                this.controllables_update();
            } else if (this.black_on_end && !this.is_faded_to_black()) {
                this.fade_to_black();
            }
        }

        /**
         * Go to the next user slide
         */
        public void next_user_page() {
            bool needs_update; // Did we change anything?
            if ( this.current_user_slide_number < this.metadata.get_user_slide_count()-1 ) {
                ++this.current_user_slide_number;
                this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
                needs_update = true;
            } else {
                if ( this.current_slide_number == this.n_slides - 1) {
                    needs_update = false;
                    if (this.black_on_end && !this.is_faded_to_black())
                        this.fade_to_black();
                } else {
                    this.current_user_slide_number = this.metadata.get_user_slide_count() - 1;
                    this.current_slide_number = this.n_slides - 1;
                    needs_update = false;
                }
            }
            if (needs_update) {
                if (!this.frozen)
                    this.faded_to_black = false;
                this.controllables_update();
            }
        }

        /**
         * Go to the previous slide
         */
        public void previous_page() {
            if ( this.current_slide_number > 0) {
                if (this.current_slide_number != this.metadata.user_slide_to_real_slide(this.current_user_slide_number)) {
                    --this.current_slide_number;
                } else {
                    --this.current_user_slide_number;
                    this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
                }
                if (!this.frozen)
                    this.faded_to_black = false;
                this.controllables_update();
            }
        }

        /**
         * Go to the previous user slide
         */
        public void previous_user_page() {
            if ( this.current_user_slide_number > 0 ) {
                --this.current_user_slide_number;
                this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
            } else {
                this.current_user_slide_number = 0;
                this.current_slide_number = 0;
            }
            if (!this.frozen)
                this.faded_to_black = false;
            this.controllables_update();
        }

        /**
         * Go to the first slide
         */
        public void goto_first() {
            if (this.current_slide_number != 0)
                this.slide2history();
            this.current_slide_number = 0;
            this.current_user_slide_number = 0;
            if (!this.frozen)
                this.faded_to_black = false;
            this.controllables_update();
        }

        /**
         * Go to the last slide
         */
        public void goto_last() {
            if (this.current_user_slide_number != this.metadata.get_end_user_slide() - 1)
                this.slide2history();
            this.current_user_slide_number = this.metadata.get_end_user_slide() - 1;
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
            if (!this.frozen)
                this.faded_to_black = false;
            this.controllables_update();
        }

        /**
         * Jump 10 (user) slides forward
         */
        public void jump10() {
            this.current_user_slide_number += 10;
            int max_user_slide = this.metadata.get_user_slide_count();
            if ( this.current_user_slide_number >= max_user_slide )
                this.current_user_slide_number = max_user_slide - 1;
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
            if (!this.frozen)
                this.faded_to_black = false;
            this.controllables_update();
        }

        /**
         * Jump 10 (user) slides backward
         */
        public void back10() {
            this.current_user_slide_number -= 10;
            if ( this.current_user_slide_number < 0 )
                this.current_user_slide_number = 0;
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
            if (!this.frozen)
                this.faded_to_black = false;
            this.controllables_update();
        }

        /**
         * Goto a slide in user page numbers
         */
        public void goto_user_page(int page_number) {
            if (this.current_user_slide_number != page_number - 1)
                this.slide2history();
            
            this.controllables_hide_overview();
            int destination = page_number-1;
            int n_user_slides = this.metadata.get_user_slide_count();
            if (page_number < 1)
                destination = 0;
            else if (page_number >= n_user_slides)
                destination = n_user_slides - 1;
            this.current_user_slide_number = destination;
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
            if (!this.frozen)
                this.faded_to_black = false;
            this.set_ignore_input_events( false );
            this.controllables_update();
        }

        /**
         * Go back in history
         */
        public void history_back() {
            int history_length = this.history.length;
            if (history_length == 0) {
                this.goto_first();
            } else {
                this.current_slide_number = this.history[history_length - 1];
                this.current_user_slide_number = this.metadata.real_slide_to_user_slide(this.current_slide_number);
                this.history.resize(history_length - 1);
                if (!this.frozen)
                    this.faded_to_black = false;
                this.controllables_update();
            }
        }

        /**
         * Notify the controllables that they have to update the view
         */
        protected void controllables_update() {
            foreach( Controllable c in this.controllables )
                c.update();
        }

        /**
         * Reset all registered controllables to their initial state
         */
        protected void controllables_reset() {
            this.current_slide_number = 0;
            this.current_user_slide_number = 0;
            this.controllables_update();
            this.reset_timer();
        }

        protected void controllables_show_overview() {
            this.set_ignore_mouse_events(true);
            this.current_key_mapping = this.KeyMappings.Overview;
            foreach( Controllable c in this.controllables )
                c.show_overview();
        }

        protected void controllables_hide_overview() {
            this.set_ignore_mouse_events(false);
            this.current_key_mapping = this.KeyMappings.Normal;
            // It may happen that in overview mode, the number of (user) slides
            // has changed due to overlay changes. We may need to correct our
            // position
            if (this.current_user_slide_number >= this.get_user_n_slides())
                this.goto_last();
            this.controllables_update();
        }

        /**
         * Fill the presentation display with black
         */
        protected void fade_to_black() {
            this.faded_to_black = !this.faded_to_black;
            this.controllables_update();
        }

        /**
         * Is the presentation blanked?
         */
        public bool is_faded_to_black() {
            return this.faded_to_black;
        }

        /**
         * Edit note for current slide.
         */
        protected void controllables_edit_note() {
            foreach( Controllable c in this.controllables ) {
                c.edit_note();
            }
        }

        /**
         * Ask for the page to jump to
         */
        protected void controllables_ask_goto_page() {
            foreach( Controllable c in this.controllables ) {
                c.ask_goto_page();
            }
        }

        /**
         * Freeze the display
         */
        protected void toggle_freeze() {
            this.frozen = !this.frozen;
            if (!this.frozen)
                this.faded_to_black = false;
            this.controllables_update();
        }

        /**
         * Is the presentation frozen?
         */
        public bool is_frozen() {
            return this.frozen;
        }
        
        /**
         * Toggle skip for current slide
         */
        protected void toggle_skip() {
            this.current_user_slide_number += this.metadata.toggle_skip( this.current_slide_number, this.current_user_slide_number);
            this.overview.set_n_slides(this.get_user_n_slides());
            this.controllables_update();
        }

        /**
         * Toggle skip for current slide in overview mode
         */
        protected void toggle_skip_overview() {
            int user_selected = this.overview.get_current_button();
            int slide_number = this.metadata.user_slide_to_real_slide(user_selected);
            this.metadata.toggle_skip( slide_number, user_selected );
            this.overview.set_n_slides( this.get_user_n_slides() );
        }

        /**
         * Start the presentation (-> timer)
         */
        protected void start() {
            // The update implicitely starts the timer
            this.controllables_update();
        }
        
        /**
         * Pause the timer
         */
        protected void toggle_pause() {
            foreach( Controllable c in this.controllables )
                c.toggle_pause();
        }

        /**
         * Reset the timer
         */
        protected void reset_timer() {
            foreach( Controllable c in this.controllables )
                c.reset_timer();
        }
    }
}
