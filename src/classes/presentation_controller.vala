/**
 * Presentation Event controller
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2010 Joachim Breitner
 * Copyright 2011, 2012 David Vilar
 * Copyright 2012 Matthias Larisch
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2012 Thomas Tschager
 * Copyright 2015 Andreas Bilke
 * Copyright 2015 Andy Barry
 * Copyright 2017 Olivier Pantalé
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

[DBus (name = "org.freedesktop.ScreenSaver")]
public interface ScreenSaver : Object {
    public abstract uint32 inhibit(string application_name, string reason) throws IOError;
    public abstract void un_inhibit(uint32 cookie) throws IOError;
}

namespace pdfpc {
    /**
     * Controller handling all the triggered events/signals
     */
    public class PresentationController : Object {

        /**
         * The currently displayed slide
         */
        public int current_slide_number { get; protected set; }

        /**
         * The current slide in "user indexes"
         */
        public int current_user_slide_number { get; protected set; }

        /**
         * Stores if the view is faded to black
         */
        public bool faded_to_black { get; protected set; default = false; }

        /**
         * Stores if the view is frozen
         */
        public bool frozen { get; protected set; default = false; }

        /**
         * The number of slides in the presentation
         */
        public int n_slides { get; protected set; }

        /**
         * The number of user slides
         */
        public int user_n_slides {
            get {
                return this.metadata.get_user_slide_count();
            }
        }

        /**
         * Presenter window showing the current and the next slide as well as
         * different other meta information useful for the person giving the
         * presentation.
         */
        public Window.Presenter presenter {
            get {
                return _presenter;
            }
            set {
                _presenter = value;
                if (value != null) {
                    presenter.current_view.size_allocate.connect(init_presenter_pointer);
                }
            }
        }
        private Window.Presenter _presenter=null;



        /**
         * Window which shows the current slide in fullscreen
         *
         * This window is supposed to be shown on the beamer
         */
        public Window.Presentation presentation {
            get {
                return _presentation;
            }
            set {
                _presentation = value;
                if (value != null) {
                    presentation.main_view.size_allocate.connect(init_presentation_pointer);
                }
            }
        }
        private Window.Presentation _presentation=null;
        public Gtk.Image presenter_pointer;
        public Gtk.Image presentation_pointer;

        public Gtk.DrawingArea presenter_surface;
        public Gtk.DrawingArea presentation_surface;

        /**
         * Key modifiers that we support
         */
        public uint accepted_key_mods = Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.META_MASK;

        /**
         * Ignore input events. Useful e.g. for editing notes.
         */
        public bool ignore_keyboard_events { get; protected set; default = false; }
        public bool ignore_mouse_events { get; protected set; default = false; }

        /**
         * Signal: Update the display
         */
        public signal void update_request();

        /**
         * Signal: Start editing notes
         */
        public signal void edit_note_request();

        /**
         * Signal: Ask for the page to jump to
         */
        public signal void ask_goto_page_request();

        /**
         * Signal: Show an overview of all slides
         */
        public signal void show_overview_request();

        /**
         * Signal: Hide the overview
         */
        public signal void hide_overview_request();

        /**
         * Signal: Increase font sizes
         */
        public signal void increase_font_size_request();

        /**
         * Signal: Decrease font sizes
         */
        public signal void decrease_font_size_request();

        /**
         * A flag signaling if we allow for a black slide at the end. Tis is
         * useful for the next view and (for some presenters) also for the main
         * view.
         */
        protected bool black_on_end;

        /**
         * Controllables which are registered with this presentation controller.
         */
        protected Gee.List<Controllable> controllables;

        /**
         * The metadata of the presentation
         */
        protected Metadata.Pdf metadata;

        /**
         * The presenters overview. We need to communicate with it for toggling
         * skips
         */
        protected Window.Overview overview;
        protected bool overview_shown = false;

        /**
         * Disables processing of multiple Keypresses at the same time (debounce)
         */
        protected uint last_key_event = 0;

        /**
         * Stores the "history" of the slides (jumps only)
         */
        private Gee.ArrayQueue<int> history;

        /**
         * Timer for the presentation. It should only be displayed on one view.
         * We hope the controllables behave accordingly.
         */
        protected TimerLabel timer;

        protected delegate void callback();
        protected SimpleActionGroup action_group = new SimpleActionGroup();

        protected class KeyDef : GLib.Object, Gee.Hashable<KeyDef> {
            public uint keycode { get; set; }
            public uint modMask { get; set; }

            public KeyDef(uint k, uint m) {
                this.keycode = k;
                this.modMask = m;
            }

            public uint hash() {
                var uintHashFunc = Gee.Functions.get_hash_func_for(Type.from_name("uint"));
                return uintHashFunc(this.keycode | this.modMask); // | is probable the best combinator, but for this small application it should suffice
            }

            public bool equal_to(KeyDef other) {
                return this.keycode == other.keycode && this.modMask == other.modMask;
            }
        }
        protected Gee.HashMap<KeyDef, Action> keyBindings = new Gee.HashMap<KeyDef, Action>();
        // We abuse the KeyDef structure
        protected Gee.HashMap<KeyDef, Action> mouseBindings = new Gee.HashMap<KeyDef, Action>();

        /*
         * "Main" view of current slide
         */
        public View.Pdf main_view = null;

        /**
         * DBus interface to screensaver
         */
        protected ScreenSaver? screensaver = null;
        protected uint32 screensaver_cookie = 0;

        /**
         * Instantiate a new controller
         */
        public PresentationController(Metadata.Pdf metadata, bool allow_black_on_end) {
            this.metadata = metadata;
            this.metadata.controller = this;
            this.black_on_end = allow_black_on_end;

            this.controllables = new Gee.ArrayList<Controllable>();

            this.history = new Gee.ArrayQueue<int>();

            // Calculate the countdown to display until the presentation has to
            // start
            time_t start_time = 0;
            if (Options.start_time != null) {
                start_time = this.parseTime(Options.start_time);
            }
            // The same again for end_time
            time_t end_time = 0;
            if (Options.end_time != null) {
                end_time = this.parseTime(Options.end_time);
                Options.duration = 0;
                this.metadata.set_duration(0);
            }
            this.timer = getTimerLabel((int) this.metadata.get_duration() * 60,
                end_time, Options.last_minutes, start_time, Options.use_time_of_day);
            this.timer.reset();

            this.n_slides = (int) this.metadata.get_slide_count();

            this.current_slide_number = 0;
            this.current_user_slide_number = 0;

            this.add_actions();

            try {
                this.screensaver = Bus.get_proxy_sync(BusType.SESSION, "org.freedesktop.ScreenSaver",
                    "/org/freedesktop/ScreenSaver");
                this.screensaver_cookie = this.screensaver.inhibit("pdfpc",
                    "Showing a presentation");
                GLib.print("Screensaver inhibited\n");
            } catch (Error error) {
                // pass
            }

            readKeyBindings();
            readMouseBindings();


            DBusServer.start_server(this, this.metadata);
        }

        private Gtk.Allocation presenter_allocation;
        private Gtk.Allocation presentation_allocation;
        private uint pointer_size = 10;
        private uint pointer_step = 10;

        private double highlight_x;
        private double highlight_y;
        private double highlight_w;
        private double highlight_h;
        private double drag_x;
        private double drag_y;
        private bool pointer_enabled = false;
        private double pointer_x;
        private double pointer_y;

        protected void init_presentation_pointer(Gtk.Allocation a) {
            presentation_allocation = a;
            presentation_surface = new Gtk.DrawingArea();
            presentation_surface.set_size_request(a.width, a.height);
            this.presentation_surface.draw.connect ((context) => {
                    draw_pointer(context, presentation_allocation);
                    return true;
                });
            presentation.add_to_fixed(presentation_surface, a.x, a.y);
        }

        protected void init_presenter_pointer(Gtk.Allocation a) {
            presenter_allocation = a;
            presenter_surface = new Gtk.DrawingArea();
            presenter_surface.set_size_request(a.width, a.height);
            this.presenter_surface.draw.connect ((context) => {
                    draw_pointer(context, presenter_allocation);
                    return true;
                });
            drag_x=-1;
            drag_y=-1;
            this.presenter_surface.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            this.presenter_surface.button_press_event.connect((event) => {
                    drag_x=event.x/presenter_allocation.width;
                    drag_y=event.y/presenter_allocation.height;
                    highlight_w=0;
                    highlight_h=0;
                    return true;
                });
            this.presenter_surface.add_events(Gdk.EventMask.BUTTON_RELEASE_MASK);
            this.presenter_surface.button_release_event.connect((event) => {
                    update_highlight(event.x/presenter_allocation.width, event.y/presenter_allocation.height);
                    drag_x=-1;
                    drag_y=-1;
                    return true;
                });
            this.presenter_surface.add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            this.presenter_surface.motion_notify_event.connect(on_move);
            presenter.add_to_fixed(presenter_surface, a.x, a.y);
            var w = presenter_surface.get_window();
            if (w != null) {
                w.set_cursor(new Gdk.Cursor.from_name(Gdk.Display.get_default(), "none"));
            }
            //presenter_surface.show();

        }

        public void move_pointer(double percent_x, double percent_y) {
            pointer_y = percent_y;
            pointer_x = percent_x;
            if (presenter!=null) presenter_surface.queue_draw();
            if (presentation!=null) presentation_surface.queue_draw();
        }

        /**
         * Handle mouse scrolling events on the window and, if neccessary send
         * them to the presentation controller
         */
        protected bool on_move( Gtk.Widget source, Gdk.EventMotion move ) {
            move_pointer(move.x / (double) presenter_allocation.width, move.y / (double) presenter_allocation.height);
            update_highlight(move.x/presenter_allocation.width, move.y/presenter_allocation.height);
            return true;
        }


        protected void update_highlight(double x, double y) {
            if (drag_x!=-1) {
                highlight_w=Math.fabs(drag_x-x);
                highlight_h=Math.fabs(drag_y-y);
                highlight_x=(drag_x<x?drag_x:x);
                highlight_y=(drag_y<y?drag_y:y);
                if (presenter!=null) presenter_surface.queue_draw();
                if (presentation!=null) presentation_surface.queue_draw();
            }
        }

        protected void draw_pointer(Cairo.Context context, Gtk.Allocation a) {
            if (pointer_enabled) {
                int x = (int)(a.width*pointer_x);
                int y = (int)(a.height*pointer_y);
                int r = (int)(a.height*0.001*pointer_size);

                if (highlight_w>0) {
                    context.rectangle(0,0,a.width, a.height);
                    context.new_sub_path();
                    context.rectangle((int)(highlight_x*a.width), (int)(highlight_y*a.height), (int)(highlight_w*a.width), (int)(highlight_h*a.height));

                    context.set_fill_rule (Cairo.FillRule.EVEN_ODD);
                    context.set_source_rgba(0,0,0,0.5);
                    context.fill_preserve();

                    //cursor
                    context.new_path();
                    context.set_source_rgba(255,0,0,0.5);
                    context.arc(x, y, r, 0, 2*Math.PI);
                    context.fill();
                } else {
                    context.set_source_rgba(255,0,0,0.5);
                    context.arc(x, y, r, 0, 2*Math.PI);
                    context.fill();
                }
            }
        }


        public void toggle_pointers() {
            pointer_enabled = !pointer_enabled;
            if (pointer_enabled) {
                if (presenter!=null) presenter_surface.show();
                if (presentation!=null) presentation_surface.show();
            } else {
                if (presenter!=null) presenter_surface.hide();
                if (presentation!=null) presentation_surface.hide();
            }
        }

        public void inc_pointer() {
            if (pointer_size<1000) pointer_size+=pointer_step;
            if (presenter!=null) presenter_surface.queue_draw();
            if (presentation!=null) presentation_surface.queue_draw();
        }

        public void dec_pointer() {
            if (pointer_size>pointer_step) pointer_size-=pointer_step;
            if (presenter!=null) presenter_surface.queue_draw();
            if (presentation!=null) presentation_surface.queue_draw();
        }


        /*
         * Inform metadata of quit, and then quit.
         */
        public void quit() {
            this.metadata.quit();
            if (this.screensaver != null && this.screensaver_cookie != 0) {
                try {
                    this.screensaver.un_inhibit(this.screensaver_cookie);
                    GLib.print("Screensaver reactivated\n");
                } catch (Error error) {
                    // pass
                }
            }
            Gtk.main_quit();
        }

        public void set_overview(Window.Overview o) {
            this.overview = o;
        }

        protected void add_actions() {
            add_action("togglePointer", this.toggle_pointers);
            add_action("increasePointer", this.inc_pointer);
            add_action("decreasePointer", this.dec_pointer);


            add_action("next", this.next_page);
            add_action("next10", this.jump10);
            add_action("lastOverlay", this.jump_to_last_overlay);
            add_action("nextOverlay", this.next_user_page);
            add_action("prev", this.previous_page);
            add_action("prev10", this.back10);
            add_action("prevOverlay", this.previous_user_page);

            add_action("goto", this.controllables_ask_goto_page);
            add_action("gotoFirst", this.goto_first);
            add_action("gotoLast", this.goto_last);
            add_action("overview", this.toggle_overview);
            add_action("histBack", this.history_back);

            add_action("start", this.start);
            add_action("pause", this.toggle_pause);
            add_action("resetTimer", this.reset_timer);
            add_action("reset", this.controllables_reset);

            add_action("blank", this.fade_to_black);
            add_action("freeze", this.toggle_freeze);
            add_action("freezeOn", () => {
                if (!this.frozen)
                    this.toggle_freeze();
                });

            add_action("overlay", this.toggle_skip);
            add_action("note", this.controllables_edit_note);
            add_action("endSlide", this.set_end_user_slide);
            add_action("lastSlide", this.set_last_saved_slide);
            add_action("jumpLastSlide", this.goto_last_saved_slide);

            add_action("increaseFontSize", this.increase_font_size);
            add_action("decreaseFontSize", this.decrease_font_size);

            add_action("exitState", this.exit_state);
            add_action("quit", this.quit);
        }

        protected void add_action(string name, callback func) {
            SimpleAction action = new SimpleAction(name, null);
            action.activate.connect(() => func());  // Trying to connect func directly causes error.
            this.action_group.add_action(action);
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
                "lastOverlay", "Jump to the last overlay of the current slide",
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
                "lastSlide", "Set last displayed slide",
                "jumpLastSlide", "Goto last displayed slide",
                "increaseFontSize", "Increase the current font size by 10%",
                "decreaseFontSize", "Decrease the current font size by 10%",
                "togglePointer", "Toggle pointer mode",
                "increasePointer", "Increase pointer size",
                "decreasePointer", "Decrease pointer size",
                "exitState", "Exit \"special\" state (pause, freeze, blank)",
                "quit", "Exit pdfpc"
            };
        }

        /**
         * Trigger an action by name
         */
        public void trigger_action(string name) {
            this.action_group.activate_action(name, null);
        }

        /**
         * Bind the (user-defined) keys
         */
        public void bind(uint keycode, uint modMask, string action_name) {
            Action? action = this.action_group.lookup_action(action_name);
            if (action != null) {
                this.keyBindings.set(new KeyDef(keycode, modMask), action);
            } else {
                GLib.printerr("Unknown action %s\n", action_name);
            }
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
        public void bindMouse(uint button, uint modMask, string action_name) {
            Action? action = this.action_group.lookup_action(action_name);
            if (action != null) {
                this.mouseBindings.set(new KeyDef(button, modMask), action);
            } else {
                GLib.printerr("Unknown action %s\n", action_name);
            }
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
        public bool key_press(Gdk.EventKey key) {
            if (key.time != last_key_event && !ignore_keyboard_events ) {
                last_key_event = key.time;
                if (this.overview_shown && this.overview.key_press_event(key))
                    return true;

                var action = this.keyBindings.get(new KeyDef(key.keyval,
                    key.state & this.accepted_key_mods));

                if (action != null)
                    action.activate(null);
                return true;
            } else {
                return false;
            }
        }

        /**
         * Handle mouse clicks to each of the controllables
         */
        public bool button_press(Gdk.EventButton button) {
            if (!ignore_mouse_events && button.type == Gdk.EventType.BUTTON_PRESS ) {
                // Prevent double or triple clicks from triggering additional
                // click events
                var action = this.mouseBindings.get(new KeyDef(button.button,
                    button.state & this.accepted_key_mods));
                if (action != null)
                    action.activate(null);
                return true;
            } else {
                return false;
            }
        }

        /**
         * Notify each of the controllables of mouse scrolling
         */
        public bool scroll(Gdk.EventScroll scroll) {
            if (!this.ignore_mouse_events) {
                switch (scroll.direction) {
                    case Gdk.ScrollDirection.UP:
                    case Gdk.ScrollDirection.LEFT:
                        if ((scroll.state & Gdk.ModifierType.SHIFT_MASK) != 0)
                            this.back10();
                        else
                            this.previous_page();
                    break;

                    case Gdk.ScrollDirection.DOWN:
                    case Gdk.ScrollDirection.RIGHT:
                        if ((scroll.state & Gdk.ModifierType.SHIFT_MASK) != 0)
                            this.jump10();
                        else
                            this.next_page();
                    break;
                }
                return true;
            }
            return false;
        }

        /**
         * Get the PDF file name
         */
        public string? get_pdf_fname() {
            return this.metadata.pdf_fname;
        }

        /**
         * Was the previous slide a skip one?
         */
        public bool skip_previous() {
            return this.current_slide_number > 0 && this.metadata.real_slide_to_user_slide(this.current_slide_number - 1) == this.metadata.real_slide_to_user_slide(this.current_slide_number);
        }

        /**
         * Is the next slide a skip one?
         */
        public bool skip_next() {
            return this.current_slide_number < this.n_slides && this.metadata.real_slide_to_user_slide(this.current_slide_number) == this.metadata.real_slide_to_user_slide(this.current_slide_number + 1);
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
         * Set the last slide as defined by the user
         */
        public void set_last_saved_slide() {
            this.metadata.set_last_saved_slide(this.current_user_slide_number + 1);
            this.controllables_update();
	    presenter.session_saved();
        }

        /**
         * Set the last slide as defined by the user
         */
        public void set_last_saved_slide_overview() {
            int user_selected = this.overview.current_slide;
            this.metadata.set_last_saved_slide(user_selected + 1);
        }

        /**
         * Register the current slide in the history
         */
        void push_history() {
            this.history.offer_head(this.current_slide_number);
        }

        /**
         * A request to change the page has been issued
         */
        public void page_change_request(int page_number, bool start_timer = true) {
            if (page_number != this.current_slide_number) {
                this.push_history();
            }

            this.current_slide_number = page_number;
            this.current_user_slide_number = this.metadata.real_slide_to_user_slide(
                this.current_slide_number);
            this.controllables_update();

            if (start_timer) {
                this.timer.start();
            }
        }

        /**
         * Set the state of ignote_input_events
         */
        public void set_ignore_input_events(bool v) {
            this.ignore_keyboard_events = v;
            this.ignore_mouse_events = v;
        }

        /**
         * Get the timer
         */
        public TimerLabel getTimer() {
            return this.timer;
        }

        private void readKeyBindings() {
            foreach (var bt in Options.key_bindings) {
                if (bt.type == "bind") {
                    bind(bt.keyCode, bt.modMask, bt.actionName);
                } else if (bt.type == "unbind") {
                    unbind(bt.keyCode, bt.modMask);
                } else if (bt.type == "unbindall") {
                    unbindAll();
                }
            }
        }

        private void readMouseBindings() {
            foreach (var bt in Options.mouse_bindings) {
                if (bt.type == "bind") {
                    bindMouse(bt.keyCode, bt.modMask, bt.actionName);
                } else if (bt.type == "unbind") {
                    unbindMouse(bt.keyCode, bt.modMask);
                } else if (bt.type == "unbindall") {
                    unbindAllMouse();
                }
            }
        }

        /**
         * Register a new Controllable instance on this controller.
         *
         * On success true is returned, in case the controllable has already been
         * registered false is returned.
         */
        public bool register_controllable(Controllable controllable) {
            if (this.controllables.contains(controllable)) {
                // The controllable has already been added.
                return false;
            }

            //controllable.set_controller( this );
            this.controllables.add(controllable);
            if (this.main_view == null)
                this.main_view = controllable.main_view;

            return true;
        }

        /**
         * Go to the next slide
         */
        public void next_page() {
            if (overview_shown)
                return;

            this.timer.start();
            // there is a next slide
            if (this.current_slide_number < this.n_slides - 1) {
                ++this.current_slide_number;
                this.current_user_slide_number = this.metadata.real_slide_to_user_slide(this.current_slide_number);

                if (!this.frozen) {
                    this.faded_to_black = false;
                }

                this.controllables_update();
            } else if (this.black_on_end && !this.faded_to_black) {
                this.fade_to_black();
            }
        }

        /**
         * Go to the next user slide
         */
        public void next_user_page() {
            this.timer.start();
            bool needs_update = false; // Did we change anything? Default: no

            // there is a next user slide
            if (this.current_user_slide_number < this.metadata.get_user_slide_count() - 1) {
                ++this.current_user_slide_number;
                this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
                needs_update = true;
            } else {
                // we are at the last slide
                if (this.current_slide_number == this.n_slides - 1) {
                    if (this.black_on_end && !this.faded_to_black) {
                        this.fade_to_black();
                    }
                } else {
                    // move to the last slide, we are already at the last user slide
                    this.current_slide_number = this.n_slides - 1;
                }
            }

            if (needs_update) {
                if (!this.frozen) {
                    this.faded_to_black = false;
                }
                this.controllables_update();
            }
        }

        /**
         * Jump to the last overlay for the current user slide
         */
        public void jump_to_last_overlay() {
            this.timer.start();
            bool needs_update = false; // Did we change anything? Default: no

            // there is a next user slide
            if (this.current_user_slide_number < this.metadata.get_user_slide_count() - 1) {
                // last overlay = next user slide (as real) - 1
                this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number + 1) - 1;
                needs_update = true;
            } else {
                // we are at the last user slide
                // last overlay == last last
                this.current_slide_number = this.n_slides - 1;
                needs_update = true;
            }

            if (needs_update) {
                if (!this.frozen) {
                    this.faded_to_black = false;
                }
                this.controllables_update();
            }
        }

        /**
         * Go to the previous slide
         */
        public void previous_page() {
            this.timer.start();

            if (this.current_slide_number > 0) {
                --this.current_slide_number;
                this.current_user_slide_number = this.metadata.real_slide_to_user_slide(this.current_slide_number);

                if (!this.frozen) {
                    this.faded_to_black = false;
                }
                this.controllables_update();
            }
        }

        /**
         * Go to the previous user slide
         */
        public void previous_user_page() {
            this.timer.start();

            if (this.current_user_slide_number > 0) {
                --this.current_user_slide_number;
                this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);
            } else {
                this.current_slide_number = 0;
            }

            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
        }

        /**
         * Wrapper function to work with key bindings and callbacks
         */
        public void goto_first() {
            _goto_first(false);
        }

        /**
         * Go to the first slide
         */
        private void _goto_first(bool skipHistory) {
            this.timer.start();

            // update history if we are not already at the first slide
            if (this.current_slide_number > 0 && !skipHistory) {
                this.push_history();
            }

            this.current_slide_number = 0;
            this.current_user_slide_number = 0;

            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
        }

        /**
         * Go to the last displayed slide
         */
        public void goto_last_saved_slide() {

            if (this.metadata.get_last_saved_slide() == -1) {
                return;
            }

            // Start the timer
            this.timer.start();

            this.current_user_slide_number = this.metadata.get_last_saved_slide() - 1;
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);

            if (!this.frozen) {
                this.faded_to_black = false;
            }

            this.controllables_update();
            presenter.session_loaded();
        }

        /**
         * Go to the last slide
         */
        public void goto_last() {
            this.timer.start();

            // if are not already at the last slide, update history
            if (this.current_user_slide_number < this.metadata.get_end_user_slide()) {
                this.push_history();
            }

            this.current_user_slide_number = this.metadata.get_end_user_slide() - 1;
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);

            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
        }

        /**
         * Jump 10 (user) slides forward
         */
        public void jump10() {
            if (this.overview_shown) {
                return;
            }

            this.timer.start();

            this.current_user_slide_number = int.min(this.current_user_slide_number + 10, this.metadata.get_user_slide_count() - 1);
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);

            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
        }

        /**
         * Jump 10 (user) slides backward
         */
        public void back10() {
            if (this.overview_shown) {
                return;
            }

            this.timer.start();

            this.current_user_slide_number = int.max(this.current_user_slide_number - 10, 0);
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number);

            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
        }

        /**
         * Goto a slide in user page numbers. page_number is 1 indexed.
         */
        public void goto_user_page(int page_number, bool useLast = true) {
            this.timer.start();

            if (this.current_user_slide_number != page_number - 1) {
                this.push_history();
            }

            this.controllables_hide_overview();
            int destination = page_number - 1;
            int n_user_slides = this.metadata.get_user_slide_count();
            if (page_number < 1) {
                destination = 0;
            } else if (page_number >= n_user_slides) {
                destination = n_user_slides - 1;
            }
            this.current_user_slide_number = destination;
            this.current_slide_number = this.metadata.user_slide_to_real_slide(this.current_user_slide_number, useLast);
            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.set_ignore_input_events(false);
            this.controllables_update();
        }

        /**
         * Go back in history
         */
        public void history_back() {
            if (this.overview_shown) {
                return;
            }

            if (this.history.is_empty) {
                // skip history pushing to prevent slide hopping
                this._goto_first(true);

                return;
            }

            int history_head = this.history.poll_head();
            this.current_slide_number = history_head;
            this.current_user_slide_number = this.metadata.real_slide_to_user_slide(this.current_slide_number);

            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
        }

        /**
         * Notify the controllables that they have to update the view
         */
        protected void controllables_update() {
            this.update_request();
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
            if (this.overview_shown) {
                this.controllables_hide_overview();
            } else {
                this.controllables_show_overview();
            }
        }

        protected void controllables_show_overview() {
            if (this.overview != null) {
                this.ignore_mouse_events = true;
                this.show_overview_request();
                this.overview_shown = true;
            }
        }

        protected void controllables_hide_overview() {
            this.ignore_mouse_events = false;
            // It may happen that in overview mode, the number of (user) slides
            // has changed due to overlay changes. We may need to correct our
            // position
            if (this.current_user_slide_number >= this.user_n_slides) {
                this.goto_last();
            }
            this.overview_shown = false;
            this.hide_overview_request();
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
         * Edit note for current slide.
         */
        protected void controllables_edit_note() {
            if (this.overview_shown) {
                return;
            }
            this.edit_note_request(); // emit signal
        }

        /**
         * Ask for the page to jump to
         */
        protected void controllables_ask_goto_page() {
            if (this.overview_shown) {
                return;
            }
            this.ask_goto_page_request();
        }

        /**
         * Freeze the display
         */
        protected void toggle_freeze() {
            this.frozen = !this.frozen;
            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
        }

        /**
         * Toggle skip for current slide
         */
        protected void toggle_skip() {
            if (overview_shown) {
                int user_selected = this.overview.current_slide;
                int slide_number = this.metadata.user_slide_to_real_slide(user_selected);
                if (this.metadata.toggle_skip(slide_number, user_selected) != 0) {
                    this.overview.remove_current(this.user_n_slides);
                }
            } else {
                this.current_user_slide_number += this.metadata.toggle_skip(
                    this.current_slide_number, this.current_user_slide_number);
                this.overview.set_n_slides(this.user_n_slides);
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

        protected void increase_font_size() {
            this.increase_font_size_request();
        }

        protected void decrease_font_size() {
            this.decrease_font_size_request();
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
        private time_t parseTime(string t) {
            var tm = Time.local(time_t());
            tm.strptime(t + ":00", "%H:%M:%S");
            return tm.mktime();
        }


#if MOVIES
        /**
         * Give the Gdk.Rectangle corresponding to the Poppler.Rectangle for the nth
         * controllable's main view.  Also, return the XID for the view's window,
         * useful for overlays.
         */
        public uint* overlay_pos(int n, Poppler.Rectangle area, out Gdk.Rectangle rect, out int gdk_scale) {
            Controllable c = (n < this.controllables.size) ? this.controllables.get(n) : null;
            // default scale, and make the compiler happy
            gdk_scale = 1;
            if (c == null) {
                rect = Gdk.Rectangle();
                return null;
            }
            View.Pdf view = c.main_view;
            if (view == null) {
                rect = Gdk.Rectangle();
                return null;
            }
            rect = view.convert_poppler_rectangle_to_gdk_rectangle(area);
            gdk_scale = view.scale_factor;
            return (uint*) ((Gdk.X11.Window) view.get_window()).get_xid();
        }
#endif
    }
}
