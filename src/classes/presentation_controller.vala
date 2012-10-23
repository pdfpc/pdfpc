/**
 * Presentation Event controller
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

using GLib;
using Gee;

namespace pdfpc {
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
        protected GLib.List<Controllable> controllables;

        /**
         * Key modifiers that we support
         */
        public uint accepted_key_mods { get; set; }

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
        public bool overview_shown = false;

        /**
         * Disables processing of multiple Keypresses at the same time (debounce)
         */
        protected uint last_key_event = 0;

        /**
         * Stores the "history" of the slides (jumps only)
         */
        private int[] history;

        /**
         * Timer for the presentation. It should only be displayed on one view.
         * We hope the controllables behave accordingly.
         */
        protected TimerLabel timer;

        /**
         * The key bindings as a map from keycodes to actions
         *
         * Vala doesn't allow for delegates as the values in a HashMap (yet?). See
         * http://stackoverflow.com/questions/6145635/gee-hashmap-containing-methods-as-values
         * for this solution.
         */
        protected class KeyAction {
            public delegate void KeyActionDelegate();
            public KeyActionDelegate d;
            public KeyAction(KeyActionDelegate d) {
                this.d = d;
            }
        }
        protected HashMap<string, KeyAction> actionNames;
        protected class KeyDef {
            public uint keycode { get; set; }
            public uint modMask { get; set; }

            public KeyDef(uint k, uint m) {
                this.keycode = k;
                this.modMask = m;
            }

            public static uint hash(void *_a) {
                KeyDef a = (KeyDef)_a;
                var uintHashFunc = Functions.get_hash_func_for(Type.from_name("uint"));
                return uintHashFunc(a.keycode | a.modMask); // | is probable the best combinator, but for this small application it should suffice
            }
            
            public static bool equal(void *_a, void *_b) {
                KeyDef a = (KeyDef) _a;
                KeyDef b = (KeyDef) _b;
                return a.keycode == b.keycode && a.modMask == b.modMask;
            }
        }
        protected HashMap<KeyDef, KeyAction> keyBindings;
        protected HashMap<KeyDef, KeyAction> mouseBindings; // We abuse the KeyDef structure

        /*
         * "Main" view of current slide
         */
        public View.Pdf main_view = null;

        /**
         * Instantiate a new controller
         */
        public PresentationController( Metadata.Pdf metadata, bool allow_black_on_end ) {
            this.metadata = metadata;
            this.metadata.controller = this;
            this.black_on_end = allow_black_on_end;

            this.controllables = new GLib.List<Controllable>();

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
            time_t end_time = 0;
            if ( Options.end_time != null ) 
            {
                end_time = this.parseTime( 
                    Options.end_time 
                );
                Options.duration = 0;
                this.metadata.set_duration(0);
            }
            this.timer = getTimerLabel( (int)this.metadata.get_duration() * 60,
                                        end_time, Options.last_minutes, start_time );
            this.timer.reset();

            this.n_slides = (int)metadata.get_slide_count();
            
            this.current_slide_number = 0;
            this.current_user_slide_number = 0;
            
            // The standard hash function for classes is to use the pointer, so we have to provide our own
            this.keyBindings = new HashMap<KeyDef, KeyAction>(KeyDef.hash, KeyDef.equal);
            this.mouseBindings = new HashMap<KeyDef, KeyAction>(KeyDef.hash, KeyDef.equal);
            this.fillActionNames();
        }

        /*
         * Inform metadata of quit, and then quit.
         */
        public void quit() {
            this.metadata.quit();
            Gtk.main_quit();
        }

        public void set_overview(Window.Overview o) {
            this.overview = o;
        }

        protected void fillActionNames() {
            this.actionNames = new HashMap<string, KeyAction>();
            this.actionNames.set("next", new KeyAction(this.next_page));
            this.actionNames.set("next10", new KeyAction(this.jump10));
            this.actionNames.set("nextOverlay", new KeyAction(this.next_user_page));
            this.actionNames.set("prev", new KeyAction(this.previous_page));
            this.actionNames.set("prev10", new KeyAction(this.back10));
            this.actionNames.set("prevOverlay", new KeyAction(this.previous_user_page));

            this.actionNames.set("goto", new KeyAction(this.controllables_ask_goto_page));
            this.actionNames.set("gotoFirst", new KeyAction(this.goto_first));
            this.actionNames.set("gotoLast", new KeyAction(this.goto_last));
            this.actionNames.set("overview", new KeyAction(this.toggle_overview));
            this.actionNames.set("histBack", new KeyAction(this.history_back));

            this.actionNames.set("start", new KeyAction(this.start));
            this.actionNames.set("pause", new KeyAction(this.toggle_pause));
            this.actionNames.set("resetTimer", new KeyAction(this.reset_timer));
            this.actionNames.set("reset", new KeyAction(this.controllables_reset));

            this.actionNames.set("blank", new KeyAction(this.fade_to_black));
            this.actionNames.set("freeze", new KeyAction(this.toggle_freeze));
            this.actionNames.set("freezeOn", new KeyAction(() => {if (!this.frozen) this.toggle_freeze();}));

            this.actionNames.set("overlay", new KeyAction(this.toggle_skip));
            this.actionNames.set("note", new KeyAction(this.controllables_edit_note));
            this.actionNames.set("endSlide", new KeyAction(this.set_end_user_slide));

            this.actionNames.set("exitState", new KeyAction(this.exit_state));
            this.actionNames.set("quit", new KeyAction(this.quit));
        }

        /**
         * Gets an array wit all function names
         *
         * It would be more legant yo use the keys property of actionNames, but
         * we would need an instance for doing this...
         */
        public static string[] getActionDescriptions() {
            return {"next", "Go to next slide",
					"next10", "Jump 10 slides forward",
					"nextOverlay", "Jump forward outside of current overlay",
					"prev", "Go to previous slide",
					"prev10", "Jump 10 slides back",
					"prevOverlay", "Jump back outside of current overlay",
					"goto", "Ask for a page to jump to",
					"gotoFirst", "Jump to first slide",
					"gotoLast", "Jump to last slide",
					"overview", "Show the overview mode",
					"histBack", "Go back in history",
					"start", "Start the timer",
					"pause", "Pause the timer",
					"resetTimer", "Reset the timer",
					"reset", "Reset the presentation",
					"blank", "Blank presentation screen",
					"freeze", "Toggle freeze presentation screen",
					"freezeOn", "Freeze presentation screen if unfrozen",
					"overlay", "Mark current slide as overlay slide",
					"note", "Edit note for current slide",
					"endSlide", "Set current slide as end slide",
					"exitState", "Exit \"special\" state (pause, freeze, blank)",
					"quit", "Exit pdfpc"
			};
        }

        /**
         * Bind the (user-defined) keys
         */
        public void bind(uint keycode, uint modMask, string function) {
            if (this.actionNames.contains(function)) {
                this.keyBindings.set(new KeyDef(keycode, modMask), this.actionNames[function]);
            } else
                stderr.printf("Warning: Unknown function %s\n", function);
        }

        /**
         * Unbind a key
         */
        public void unbind(uint keycode, uint modMask) {
            this.keyBindings.unset(new KeyDef(keycode, modMask));
        }

        /**
         * Unbind all keybindings
         */
        public void unbindAll() {
            this.keyBindings.clear();
        }

        /**
         * Bind the (user-defined) keys
         */
        public void bindMouse(uint button, uint modMask, string function) {
            if (this.actionNames.contains(function)) {
                this.mouseBindings.set(new KeyDef(button, modMask), this.actionNames[function]);
            } else
                stderr.printf("Warning: Unknown function %s\n", function);
        }

        /**
         * Unbind a mouse button
         */
        public void unbindMouse(uint keycode, uint modMask) {
            this.mouseBindings.unset(new KeyDef(keycode, modMask));
        }

        /**
         * Unbind all keybindings
         */
        public void unbindAllMouse() {
            this.mouseBindings.clear();
        }

        /**
         * Handle keypresses to each of the controllables
         *
         * This seperate handling is needed because keypresses from any of the
         * window have implications on the behaviour of both of them. Therefore
         * this controller is needed to take care of the needed actions.
         */
        public bool key_press( Gdk.EventKey key ) {
            if (key.time != last_key_event && !ignore_keyboard_events ) {
                last_key_event = key.time;
                var action = this.keyBindings.get(new KeyDef(key.keyval,key.state & this.accepted_key_mods));
                if (action != null)
                    action.d();
                return true;
            } else {
                return false;
            }
        }

        /**
         * Handle mouse clicks to each of the controllables
         */
        public bool button_press( Gdk.EventButton button ) {
            if ( !ignore_mouse_events && button.type ==
                    Gdk.EventType.BUTTON_PRESS ) {
                // Prevent double or triple clicks from triggering additional
                // click events
                var action = this.mouseBindings.get(new KeyDef(button.button,button.state & this.accepted_key_mods));
                if (action != null)
                    action.d();
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
         * Get the PDF URL
         */
        public string? get_pdf_url() {
            return this.metadata.pdf_url;
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
            int user_selected = this.overview.current_slide;
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
            this.timer.start();
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
         * Get the timer
         */
        public TimerLabel getTimer() {
            return this.timer;
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
            if (this.main_view == null)
                this.main_view = controllable.get_main_view();
            
            return true;
        }

        /**
         * Go to the next slide
         */
        public void next_page() {
            if (overview_shown)
                return;
            this.timer.start();
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
            this.timer.start();
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
            this.timer.start();
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
            this.timer.start();
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
            this.timer.start();
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
            this.timer.start();
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
            if (this.overview_shown)
                return;
            this.timer.start();
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
            if (this.overview_shown)
                return;
            this.timer.start();
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
            this.timer.start();
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
            if (this.overview_shown)
                return;
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

        protected void toggle_overview() {
            if (this.overview_shown)
                this.controllables_hide_overview();
            else
                this.controllables_show_overview();
        }

        protected void controllables_show_overview() {
            if (this.overview != null) {
                this.set_ignore_mouse_events(true);
                foreach( Controllable c in this.controllables )
                    c.show_overview();
                this.overview_shown = true;
            }
        }

        protected void controllables_hide_overview() {
            this.set_ignore_mouse_events(false);
            // It may happen that in overview mode, the number of (user) slides
            // has changed due to overlay changes. We may need to correct our
            // position
            if (this.current_user_slide_number >= this.get_user_n_slides())
                this.goto_last();
            this.overview_shown = false;
            foreach( Controllable c in this.controllables )
                c.hide_overview();
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
            if (this.overview_shown)
                return;
            foreach( Controllable c in this.controllables ) {
                c.edit_note();
            }
        }

        /**
         * Ask for the page to jump to
         */
        protected void controllables_ask_goto_page() {
            if (this.overview_shown)
                return;
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
            if (overview_shown) {
                int user_selected = this.overview.current_slide;
                int slide_number = this.metadata.user_slide_to_real_slide(user_selected);
                if (this.metadata.toggle_skip( slide_number, user_selected ) != 0)
                    this.overview.remove_current( this.get_user_n_slides() );
            } else {
                this.current_user_slide_number += this.metadata.toggle_skip( this.current_slide_number, this.current_user_slide_number);
                this.overview.set_n_slides(this.get_user_n_slides());
                this.controllables_update();
            }
        }

        /**
         * Start the presentation (-> timer)
         */
        protected void start() {
            this.timer.start();
            this.controllables_update();
        }
        
        /**
         * Pause the timer
         */
        protected void toggle_pause() {
            this.timer.pause();
            this.controllables_update();
        }

        /**
         * Reset the timer
         */
        protected void reset_timer() {
            this.timer.reset();
        }

        protected void exit_state() {
            if (this.faded_to_black) {
                this.fade_to_black();
            }
            if (this.frozen) {
                this.toggle_freeze();
            }
            if (this.timer.is_paused()) {
                this.toggle_pause();
            }
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
         * Give the Gdk.Rectangle corresponding to the Poppler.Rectangle for the nth
         * controllable's main view.  Also, return the XID for the view's window,
         * useful for overlays.
         */
        public uint overlay_pos(int n, Poppler.Rectangle area, out Gdk.Rectangle rect) {
            Controllable c = this.controllables.nth_data(n);
            if (c == null) {
                rect = Gdk.Rectangle();
                return 0;
            }
            View.Pdf view = c.get_main_view();
            if (view == null) {
                rect = Gdk.Rectangle();
                return 0;
            }
            rect = view.convert_poppler_rectangle_to_gdk_rectangle(area);
            return (uint)Gdk.x11_drawable_get_xid(view.get_window());
        }
    }
}
