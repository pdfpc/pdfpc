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
         * The biggest slide number that we allow (dependent on black_on_end)
         */
        protected int slide_limit;


        /**
         * Controllables which are registered with this presentation controller.
         */
        protected List<Controllable> controllables;

        /**
         * Ignore input events. Useful e.g. for editing notes.
         */
        protected bool ignore_input_events = false;

        /**
         * The metadata of the presentation
         */
        protected Metadata.Pdf metadata;

        /**
         * Instantiate a new controller
         */
        public PresentationController( Metadata.Pdf metadata, bool allow_black_on_end ) {
            this.controllables = new List<Controllable>();

            this.metadata = metadata;

            this.n_slides = (int)metadata.get_slide_count();
            this.black_on_end = allow_black_on_end;
            if (this.black_on_end)
                this.slide_limit = this.n_slides + 1;
            else
                this.slide_limit = this.n_slides;
            
            this.current_slide_number = 0;
            this.current_user_slide_number = 0;
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
        public bool key_press( Gdk.EventKey key ) {
            if ( !ignore_input_events ) {
                switch( key.keyval ) {
                    case 0xff0d: /* Return */
                    case 0xff53: /* Cursor right */
                    case 0xff56: /* Page down */
                    case 0x020:  /* Space */
                        this.next_page();
                    break;
                    case 0xff54: /* Cursor down */
                        this.next_user_page();
                    break;
                    case 0x06e:  /* n */
                        this.jump10();
                    break;
                    case 0xff51: /* Cursor left */
                    case 0xff55: /* Page Up */
                        this.previous_page();
                    break;
                    case 0xff52: /* Cursor up */
                        this.previous_user_page();
                    break;
                    case 0xff08: /* Backspace */
                    case 0x070: /* p */
                        this.back10();
                    break;
                    case 0xff1b: /* Escape */
                    case 0x071:  /* q */
                        this.metadata.save_to_disk();
                        Gtk.main_quit();
                    break;
                    case 0xff50: /* Home */
                        this.controllables_reset();
                    break;
                    case 0x062: /* b*/
                        this.fade_to_black();
                    break;
                    case 0x065: /* e */
                        this.controllables_edit_note();
                    break;
                    case 0x067: /* g */
                        this.controllables_ask_goto_page();
                    break;
                    case 0x066: /* f */
                        this.toggle_freeze();
                    break;
                    case 0x073: /* s */
                        this.toggle_skip();
                    break;
                }
                return true;
            } else {
                return false;
            }
        }

        /**
         * Handle mouse clicks to each of the controllables
         */
        public bool button_press( Gdk.EventButton button ) {
            if ( !ignore_input_events ) {
                switch( button.button ) {
                    case 1: /* Left button */
                        this.next_page();
                    break;
                    case 3: /* Right button */
                        this.previous_page();
                    break;
                }
                return true;
            } else {
                return false;
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
         * A request to change the page has been issued
         */
        public void page_change_request( int page_number ) {
            this.current_slide_number = page_number;
            // Here we could do a binary search
            for (int u = 0; u < this.metadata.get_user_slide_count(); ++u) {
                if (page_number <= this.metadata.user_slide_to_real_slide(u)) {
                    this.current_user_slide_number = u;
                    break;
                }
            }
            this.controllables_update();
        }

        /**
         * Set the state of ignote_input_events
         */
        public void set_ignore_input_events( bool v ) {
            ignore_input_events = v;
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
            if ( this.current_slide_number < this.slide_limit - 1 ) {
                ++this.current_slide_number;
                if (this.current_slide_number == this.metadata.user_slide_to_real_slide(this.current_user_slide_number + 1))
                    ++this.current_user_slide_number;
                if (!this.frozen)
                    this.faded_to_black = false;
                this.controllables_update();
            }
        }

        /**
         * Go to the next user slide
         */
        public void next_user_page() {
            if ( this.current_user_slide_number < this.metadata.get_user_slide_count()-1 ) {
                ++this.current_user_slide_number;
                this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
            } else {
                this.current_user_slide_number = this.metadata.get_user_slide_count() - 1;
                this.current_slide_number = this.n_slides - 1;
            }
            if (!this.frozen)
                this.faded_to_black = false;
            this.controllables_update();
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
            this.controllables_update();
        }

        /**
         * Notify the controllables that they have to update the view
         */
        protected void controllables_update() {
            foreach( Controllable c in this.controllables ) {
                c.update();
            }
        }

        /**
         * Reset all registered controllables to their initial state
         */
        protected void controllables_reset() {
            this.current_slide_number = 0;
            this.current_user_slide_number = 0;
            foreach( Controllable c in this.controllables ) {
                c.update();
                c.reset();
            }
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
            this.controllables_update();
        }
    }
}
