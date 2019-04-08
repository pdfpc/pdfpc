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
 * Copyright 2015,2017 Andreas Bilke
 * Copyright 2015 Andy Barry
 * Copyright 2017 Olivier Pantalé
 * Copyright 2017 Philipp Berndt
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
    public abstract async uint32 inhibit(string application_name, string reason) throws DBusError, IOError;
    public abstract void un_inhibit(uint32 cookie) throws DBusError, IOError;
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
         * Stores if the view is hidden
         */
        public bool hidden { get; protected set; default = false; }

        /**
         * Stores if the view is frozen
         */
        public bool frozen { get; protected set; default = false; }

        /**
         * The number of slides in the presentation
         */
        public uint n_slides {
            get {
                return this.metadata.get_slide_count();
            }
        }

        /**
         * The number of user slides
         */
        public int user_n_slides {
            get {
                return this.metadata.get_user_slide_count();
            }
        }

        /**
         * CacheStatus object, which coordinates all the information about
         * cached slides to provide a visual feedback to the user about the
         * rendering state
         */
        public CacheStatus cache_status { get; protected set; }

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
                    this.register_controllable(value);

                    this.init_pen_and_pointer();
                    this.register_mouse_handlers();
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
                    this.register_controllable(value);
                }
            }
        }
        private Window.Presentation _presentation=null;

        private bool single_screen_mode {
            get {
                return (this._presentation == null ||
                        this._presenter == null);
            }
        }

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
         * Signal: Fired on document reload
         */
        public signal void reload_request();

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
         * Controllables which are registered with this presentation controller.
         */
        protected Gee.List<Controllable> controllables;

        /**
         * The metadata of the presentation
         */
        private Metadata.Pdf _metadata;
        public Metadata.Pdf metadata {
            get {
                return _metadata;
            }
            set {
                _metadata = value;
                if (value != null) {
                    this.metadata.controller = this;

                    this.user_slide_progress =
                        new int[metadata.get_user_slide_count()];

                    this.timer = getTimerLabel(this,
                        (int) this.metadata.get_duration() * 60);
                    this.timer.reset();

                    this.current_slide_number = 0;
                    this.current_user_slide_number = 0;

                    this.pen_drawing = Drawings.create(metadata);
                    current_pen_drawing_tool = pen_drawing.pen;
                }
            }
        }

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
         * Progress tracking for user slides
         */
        protected int[] user_slide_progress;

        /**
         * Timer for the presentation. It should only be displayed on one view.
         * We hope the controllables behave accordingly.
         */
        protected TimerLabel timer;

        protected delegate void callback();
        protected delegate void callback_with_parameter(GLib.Variant? parameter);
        protected SimpleActionGroup action_group = new SimpleActionGroup();

        protected class ActionDescription : GLib.Object {
            public string name { get; set; }
            public string description { get; set; }
            public string arg_name { get; set; }
            public Gee.ArrayList<KeyDef> bindings { get; set; }

            public ActionDescription(string name, string description,
                string? arg_name = null) {
                this.name = name;
                this.description = description;
                this.arg_name = arg_name;
            }
        }

        protected Gee.ArrayList<ActionDescription> action_descriptions =
            new Gee.ArrayList<ActionDescription>();

        protected class KeyDef : GLib.Object, Gee.Hashable<KeyDef> {
            public uint keycode { get; set; }
            public uint modMask { get; set; }

            public KeyDef(uint k, uint m) {
                this.keycode = k;
                this.modMask = m;
            }

            public uint hash() {
                // see gdk/gdkkeysyms.h modMask is usally in the form of
                // 0xFF??. Keycodes are usally 0x??. We shift modMask by 8 bits
                // to combine both codes.
                return (this.modMask << 8) | this.keycode;
            }

            public bool equal_to(KeyDef other) {
                return this.keycode == other.keycode && this.modMask == other.modMask;
            }
        }

        protected class ActionAndParameter : GLib.Object {
            public GLib.Action action { get; set; }
            public GLib.Variant? parameter { get; set; }
            public string name { get; set; }

            public ActionAndParameter(GLib.Action action,
                GLib.Variant? parameter, string name) {
                this.action = action;
                this.parameter = parameter;
                this.name = name;
            }
        }

        protected Gee.HashMap<KeyDef, ActionAndParameter> keyBindings =
            new Gee.HashMap<KeyDef, ActionAndParameter>();
        // We abuse the KeyDef structure
        protected Gee.HashMap<KeyDef, ActionAndParameter> mouseBindings =
            new Gee.HashMap<KeyDef, ActionAndParameter>();

        /**
         * DBus interface to screensaver
         */
        protected ScreenSaver? screensaver = null;
        protected uint32 screensaver_cookie = 0;

        /**
         * Operation mode
         */
        public enum AnnotationMode {
            NORMAL,
            POINTER,
            PEN,
            ERASER;

            public static AnnotationMode parse(string? mode_str) {
                if (mode_str == null) {
                    return NORMAL;
                }

                switch (mode_str.down()) {
                    case "normal":
                        return NORMAL;
                    case "pointer":
                        return POINTER;
                    case "pen":
                        return PEN;
                    case "eraser":
                        return ERASER;
                    default:
                        return NORMAL;
                }
            }
        }

        private AnnotationMode annotation_mode = AnnotationMode.NORMAL;

        /**
         * Instantiate a new controller
         */
        public PresentationController() {
            this.controllables = new Gee.ArrayList<Controllable>();

            this.cache_status = new CacheStatus();

            this.history = new Gee.ArrayQueue<int>();

            this.timer = getTimerLabel(this, 0);
            this.timer.reset();

            this.add_actions();

            readKeyBindings();
            readMouseBindings();

            Bus.get_proxy.begin<ScreenSaver>(BusType.SESSION,
                "org.freedesktop.ScreenSaver",
                "/org/freedesktop/ScreenSaver",
                0, null, (obj, res) => {
                try {
                    this.screensaver = Bus.get_proxy.end(res);
                    this.screensaver.inhibit.begin("pdfpc",
                        "Showing a presentation", (obj, res) => {
                        try {
                            this.screensaver_cookie =
                                this.screensaver.inhibit.end(res);
                            GLib.print("Screensaver inhibited\n");
                        } catch (GLib.Error error) {
                            // pass
                        }
                    });
                } catch (GLib.Error error) {
                    // pass
                }
            });

            DBusServer.start_server(this);
        }

        public Drawings.Drawing pen_drawing;
        public Drawings.DrawingTool? current_pen_drawing_tool = null;

        /* pen drawing state */
        private bool pen_drawing_present = false;

        private uint pen_step = 2;
        public double pen_last_x;
        public double pen_last_y;
        private bool pen_is_pressed = false;

        public bool is_pointer_active() {
            return this.annotation_mode == AnnotationMode.POINTER;
        }

        public bool is_eraser_active() {
            return annotation_mode == AnnotationMode.ERASER;
        }

        public bool is_pen_active() {
            return annotation_mode == AnnotationMode.PEN;
        }

        public bool in_drawing_mode() {
            return is_eraser_active() || is_pen_active();
        }

        private void move_pen(double x, double y) {
            if (this.pen_is_pressed) {
                pen_drawing.add_line(this.current_pen_drawing_tool, this.pen_last_x, this.pen_last_y, x, y);
            }
            this.pen_last_x = x;
            this.pen_last_y = y;
            queue_pen_surface_draws();
        }

        public void increase_pen_size() {
            if (current_pen_drawing_tool.width < 500) {
                current_pen_drawing_tool.width += pen_step;
            }
            queue_pen_surface_draws();
        }

        public void decrease_pen_size() {
            if (current_pen_drawing_tool.width > pen_step) {
                current_pen_drawing_tool.width -= pen_step;
            }
            queue_pen_surface_draws();
        }

        public void set_pen_size(double width) {
            if (width > 500) {
                width = 500;
            } else
            if (width < pen_step) {
                width = pen_step;
            }
            current_pen_drawing_tool.width = width;
        }

        public double get_pen_size() {
            return current_pen_drawing_tool.width;
        }

        public void queue_pen_surface_draws() {
            if (presenter != null) {
                presenter.pen_drawing_surface.queue_draw();
            }
            if (presentation != null) {
                presentation.pen_drawing_surface.queue_draw();
            }
        }

        protected void update_pen_drawing() {
            pen_drawing.switch_to_slide(
                this.metadata.user_slide_to_real_slide(this.current_user_slide_number)
            );
            this.queue_pen_surface_draws();
        }

        private void hide_or_show_pen_surfaces() {
            if (pen_drawing_present) {
                if (presenter != null) {
                    presenter.enable_pen(true);
                }
                if (presentation != null) {
                    presentation.enable_pen(true);
                }
                queue_pen_surface_draws();
            } else {
                if (presenter != null) {
                    presenter.enable_pen(false);
                }
                if (presentation != null) {
                    presentation.enable_pen(false);
                }
            }
        }

        private void hide_or_show_pointer_surfaces() {
            if (this.annotation_mode == AnnotationMode.POINTER) {
                if (presenter != null) {
                    presenter.enable_pointer(true);
                }
                if (presentation != null) {
                    presentation.enable_pointer(true);
                }
            } else {
                if (presenter != null) {
                    presenter.enable_pointer(false);
                }
                if (presentation != null) {
                    presentation.enable_pointer(false);
                }
            }
        }

        public void set_mode(AnnotationMode mode) {
            if (this.annotation_mode == mode) {
                return;
            }

            this.annotation_mode = mode;

            switch (mode) {
                case AnnotationMode.NORMAL:
                break;

                case AnnotationMode.POINTER:
                break;

                case AnnotationMode.PEN:
                    pen_drawing_present = true;
                    current_pen_drawing_tool = pen_drawing.pen;
                break;

                case AnnotationMode.ERASER:
                    pen_drawing_present = true;
                    current_pen_drawing_tool = pen_drawing.eraser;
                    // abort any drawing currently in progress
                    pen_is_pressed = false;
                break;
            }

            // Update pointer surfaces
            hide_or_show_pointer_surfaces();

            // Update drawing surfaces
            hide_or_show_pen_surfaces();

            if (this.presenter != null) {
                // Disable event compression for smoother drawing
                this.presenter.get_window().set_event_compression(!in_drawing_mode());
            }

            this.controllables_update();
        }

        public void set_normal_mode() {
            this.set_mode(AnnotationMode.NORMAL);
        }

        public void set_pointer_mode() {
            this.set_mode(AnnotationMode.POINTER);
        }

        public void set_pen_mode() {
            this.set_mode(AnnotationMode.PEN);
        }

        public void set_eraser_mode() {
            this.set_mode(AnnotationMode.ERASER);
        }

        public void toggle_drawings() {
            pen_drawing_present = !pen_drawing_present;
            if (!pen_drawing_present && in_drawing_mode()) {
                this.set_mode(AnnotationMode.NORMAL);
            } else {
                hide_or_show_pen_surfaces();
            }
        }

        public void clear_pen_drawing() {
            if (pen_drawing_present) {
                pen_drawing.clear();
                queue_pen_surface_draws();
            }
        }

        private void init_pen_and_pointer() {
            pointer_size = Options.pointer_size;
            if (pointer_size > 500) {
                pointer_size = 500;
            }
            if (pointer_color.parse(Options.pointer_color) != true) {
                GLib.printerr("Cannot parse color specification '%s'\n",
                    Options.pointer_color);
                pointer_color.parse("red");
            }
            if (Options.pointer_opacity >= 0 && Options.pointer_opacity <= 100) {
                pointer_color.alpha = (double) Options.pointer_opacity/100.0;
            } else {
                pointer_color.alpha = 1.0;
            }

            this.update_request.connect(this.update_pen_drawing);
        }

        public uint pointer_size;
        private uint pointer_step = 5;
        public Gdk.RGBA pointer_color;

        /**
         * Normalized coordinates (0 .. 1), i.e. mapped to a unity square
         */
        public double highlight_x;
        public double highlight_y;
        public double highlight_w;
        public double highlight_h;
        public double drag_x = -1;
        public double drag_y = -1;
        public double pointer_x;
        public double pointer_y;

        /**
         * Convert device coordinates to normalized ones
         */
        private void device_to_normalized(double dev_x, double dev_y,
            out double x, out double y) {
            var view = this.presenter.main_view;
            Gtk.Allocation a;
            view.get_allocation(out a);

            x = dev_x/a.width;
            y = dev_y/a.height;
        }

        private void queue_pointer_surface_draws() {
            if (presenter != null) {
                presenter.pointer_drawing_surface.queue_draw();
            }
            if (presentation != null) {
                presentation.pointer_drawing_surface.queue_draw();
            }
        }

        protected void register_mouse_handlers() {
            var view = presenter.main_view;
            view.set_events(
                  Gdk.EventMask.BUTTON_PRESS_MASK
                | Gdk.EventMask.BUTTON_RELEASE_MASK
                | Gdk.EventMask.POINTER_MOTION_MASK
            );

            view.motion_notify_event.connect(on_motion);
            view.button_press_event.connect(on_button_press);
            view.button_release_event.connect(on_button_release);
        }

        /**
         * Handle mouse events on the window and, if necessary send
         * them to the presentation controller
         */
        private bool on_motion(Gdk.EventMotion event) {
            if (this.annotation_mode == AnnotationMode.POINTER) {
                return on_move_pointer(event);
            } else if (this.in_drawing_mode()) {
                return on_move_pen(event);
            } else {
                return false;
            }
        }

        private bool on_button_press(Gdk.EventButton event) {
            if (this.annotation_mode == AnnotationMode.POINTER) {
                this.device_to_normalized(event.x, event.y,
                    out drag_x, out drag_y);
                highlight_w = 0;
                highlight_h = 0;
                return true;
            } else if (this.in_drawing_mode()) {
                double x, y;
                this.device_to_normalized(event.x, event.y, out x, out y);
                move_pen(x, y);
                pen_is_pressed = true;
                return true;
            } else {
                return false;
            }
        }

        private bool on_button_release(Gdk.EventButton event) {
            if (this.annotation_mode == AnnotationMode.POINTER) {
                double x, y;
                this.device_to_normalized(event.x, event.y, out x, out y);
                update_highlight(x, y);
                drag_x = -1;
                drag_y = -1;
                return true;
            } else if (this.in_drawing_mode()) {
                double x, y;
                this.device_to_normalized(event.x, event.y, out x, out y);
                move_pen(x, y);
                pen_is_pressed = false;
                return true;
            } else {
                return false;
            }
        }

        private bool on_move_pen(Gdk.EventMotion event) {
            if (!Options.disable_input_autodetection) {
                Gdk.InputSource source_type =
                    event.get_source_device().get_source();
                if (source_type == Gdk.InputSource.ERASER) {
                    this.set_mode(AnnotationMode.ERASER);
                } else if (source_type == Gdk.InputSource.PEN) {
                    this.set_mode(AnnotationMode.PEN);
                }
            }

            double x, y;
            this.device_to_normalized(event.x, event.y, out x, out y);
            move_pen(x, y);

            return true;
        }

        private bool on_move_pointer(Gdk.EventMotion event) {
            this.device_to_normalized(event.x, event.y,
                out pointer_x, out pointer_y);
            if (presenter != null) {
                presenter.pointer_drawing_surface.queue_draw();
            }
            if (presentation != null) {
                presentation.pointer_drawing_surface.queue_draw();
            }
            update_highlight(pointer_x, pointer_y);
            return true;
        }

        private void update_highlight(double x, double y) {
            if (drag_x!=-1) {
                highlight_w=Math.fabs(drag_x-x);
                highlight_h=Math.fabs(drag_y-y);
                highlight_x=(drag_x<x?drag_x:x);
                highlight_y=(drag_y<y?drag_y:y);
                queue_pointer_surface_draws();
            }
        }


        public void increase_pointer_size() {
            if (pointer_size<500) pointer_size+=pointer_step;
            queue_pointer_surface_draws();
        }

        public void decrease_pointer_size() {
            if (pointer_size>pointer_step) pointer_size-=pointer_step;
            queue_pointer_surface_draws();
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

        public void set_pen_color_to_string(Variant? color_variant) {
            if (in_drawing_mode()) {
                Gdk.RGBA color = Gdk.RGBA();
                color.parse(color_variant.get_string());
                pen_drawing.pen.set_rgba(color);
                queue_pen_surface_draws();
            }
        }

        public void set_mode_to_string(Variant? mode_variant) {
            this.set_mode(AnnotationMode.parse(mode_variant.get_string()));
        }

        protected void add_actions() {
            add_action("next", this.next_page,
                "Go to the next slide");
            add_action("next10", this.jump10,
                "Jump 10 slides forward");
            add_action("lastOverlay", this.jump_to_last_overlay,
                "Jump to the last overlay of the current slide");
            add_action("nextOverlay", this.next_user_page,
                "Jump forward outside of the current overlay");
            add_action("prev", this.previous_page,
                "Go to the previous slide");
            add_action("prev10", this.back10,
                "Jump 10 slides back");
            add_action("firstOverlay", this.jump_to_first_overlay,
                "Jump to the first overlay of the current slide");
            add_action("prevOverlay", this.previous_user_page,
                "Jump back outside of the current overlay");

            add_action("goto", this.controllables_ask_goto_page,
                "Ask for a page to jump to");
            add_action("gotoFirst", this.goto_first,
                "Jump to the first slide");
            add_action("gotoLast", this.goto_last,
                "Jump to the last slide");
            add_action("nextUnseen", this.next_unseen,
                "Jump to the next unseen slide");
            add_action("prevSeen", this.previous_seen,
                "Jump to the last previously seen slide");
            add_action("overview", this.toggle_overview,
                "Show the overview mode");
            add_action("histBack", this.history_back,
                "Go back in history");
            add_action_with_parameter("gotoPage", GLib.VariantType.STRING,
                this.goto_string,
                "Jump to the specified page", "number");

            add_action("start", this.start,
                "Start the timer");
            add_action("pause", this.toggle_pause,
                "Pause the timer");
            add_action("resetTimer", this.reset_timer,
                "Reset the timer");

            add_action("windowed", this.toggle_windowed,
                "Toggle the windowed state");

            add_action("blank", this.fade_to_black,
                "Blank the presentation screen");
            add_action("hide", this.hide_presentation,
                "Hide the presentation screen");
            add_action("freeze", this.toggle_freeze,
                "Toggle freeze the presentation screen");
            add_action("freezeOn", () => {
                if (!this.frozen)
                    this.toggle_freeze();
                },
                "Freeze the presentation screen");

            add_action("overlay", this.toggle_skip,
                "Mark the current slide as an overlay slide");
            add_action("note", this.controllables_edit_note,
                "Edit notes for the current slide");
            add_action("endSlide", this.set_end_user_slide,
                "Set the current slide as the end slide");
            add_action("saveBookmark", this.set_last_saved_slide,
                "Bookmark the currently displayed slide");
            add_action("loadBookmark", this.goto_last_saved_slide,
                "Load the bookmarked slide");

            add_action_with_parameter("switchMode", GLib.VariantType.STRING,
                this.set_mode_to_string,
                "Switch annotation mode (normal|pointer|pen|eraser)", "mode");

            add_action("increaseSize", this.increase_size,
                "Increase the size of notes|pointer|pen|eraser");
            add_action("decreaseSize", this.decrease_size,
                "Decrease the size of notes|pointer|pen|eraser");

            add_action_with_parameter("setPenColor", GLib.VariantType.STRING,
                this.set_pen_color_to_string,
                "Change the pen color", "color");
            add_action("clearDrawing", this.clear_pen_drawing,
                "Clear drawing on the current slide");
            add_action("toggleDrawings", this.toggle_drawings,
                "Toggle all drawings on all slides");

            add_action("toggleToolbox", this.toggle_toolbox,
                "Toggle the toolbox");

            add_action("showHelp", this.show_help,
                "Show a help screen");

            add_action("exitState", this.exit_state,
                "Exit \"special\" state (pause, freeze, blank)");
            add_action("reload", this.reload,
                "Reload the presentation");
            add_action("quit", this.quit,
                "Exit pdfpc");
        }

        protected void add_action(string name, callback func,
            string description) {
            SimpleAction action = new SimpleAction(name, null);
            action.activate.connect(() => func());
            this.action_group.add_action(action);
            this.action_descriptions.add(new ActionDescription(name,
                description));
        }

        protected void add_action_with_parameter(string name,
            GLib.VariantType param_type, callback_with_parameter func,
            string description, string arg_name) {
            SimpleAction action = new SimpleAction(name, param_type);
            action.activate.connect((param) => func(param));
            this.action_group.add_action(action);
            this.action_descriptions.add(new ActionDescription(name,
                description, arg_name));
        }

        /**
         * Get an array with all action names & descriptions
         */
        public string[] get_action_descriptions() {
            string[] retval = {};
            foreach (var entry in this.action_descriptions) {
                if (entry.arg_name != null) {
                    retval += (entry.name + " <" + entry.arg_name + ">");
                } else {
                    retval += entry.name;
                }
                retval += entry.description;
            }
            return retval;
        }

        private string get_bindstr(KeyDef keydef, bool is_mouse) {
            string bindstr = "", keystr, modstr = "";
            if ((keydef.modMask & Gdk.ModifierType.CONTROL_MASK) != 0) {
                modstr = "Ctrl+";
            }
            if ((keydef.modMask & Gdk.ModifierType.META_MASK) != 0) {
                modstr = "Meta+";
            }
            if ((keydef.modMask & Gdk.ModifierType.SHIFT_MASK) != 0) {
                modstr = "Shift+";
            }
            if (is_mouse) {
                keystr = "Mouse_%u".printf(keydef.keycode);
            } else {
                keystr = Gdk.keyval_name(keydef.keycode);
                // Simple "shifted" keycodes have been capitalized
                // by ConfigFileReader.readBindDef()
                if (keystr.length == 1) {
                    keystr = keystr.down();
                }
            }
            bindstr += modstr + keystr;
            return bindstr;
        }

        /**
         * Get an array with all action names & their bindings
         */
        public string[] get_action_bindings() {
            string[] retval = {};

            foreach (var entry in this.action_descriptions) {
                var bindstr = "";
                // Loop over the key bindings
                foreach (var bentry in this.keyBindings.entries) {
                    if (bentry.value.name != entry.name) {
                        continue;
                    }
                    var keydef = bentry.key;

                    if (bindstr != "") {
                        bindstr += ", ";
                    }
                    bindstr += get_bindstr(keydef, false);

                    var action = this.keyBindings.get(keydef);
                    if (action != null && action.parameter != null) {
                        bindstr += " [" + action.parameter.get_string() + "]";
                    }
                }
                // Same for the mouse bindings
                foreach (var bentry in this.mouseBindings.entries) {
                    if (bentry.value.name != entry.name) {
                        continue;
                    }
                    var keydef = bentry.key;

                    if (bindstr != "") {
                        bindstr += ", ";
                    }
                    bindstr += get_bindstr(keydef, true);

                    var action = this.keyBindings.get(keydef);
                    if (action != null && action.parameter != null) {
                        bindstr += " [" + action.parameter.get_string() + "]";
                    }
                }
                if (bindstr != "") {
                    retval += entry.name;
                    retval += bindstr;
                }
            }

            return retval;
        }

        /**
         * Trigger an action by name
         */
        public void trigger_action(string name, Variant? parameter) {
            this.action_group.activate_action(name, parameter);
        }

        /**
         * Bind the (user-defined) key or mouse button
         */
        private void bindKeyOrMouse(bool is_mouse, uint keycode, uint modMask,
            string action_name, GLib.Variant? parameter) {
            Action? action = this.action_group.lookup_action(action_name);
            if (action != null) {
                GLib.VariantType expected_type = action.get_parameter_type();
                if (expected_type == null) {
                    if (parameter != null) {
                        GLib.printerr("Action %s does not expect a parameter\n",
                            action_name);
                    }
                } else if (parameter == null) {
                    GLib.printerr("Action %s expects a parameter\n",
                        action_name);
                } else {
                    assert(
                        parameter.get_type().equal(GLib.VariantType.STRING) &&
                        expected_type.equal(GLib.VariantType.STRING)
                    );
                }
                Gee.HashMap<KeyDef, ActionAndParameter> bindings;
                if (is_mouse) {
                    bindings = this.mouseBindings;
                } else {
                    bindings = this.keyBindings;
                }
                var keydef = new KeyDef(keycode, modMask);
                bindings.set(keydef,
                    new ActionAndParameter(action, parameter, action_name));
            } else {
                GLib.printerr("Unknown action %s\n", action_name);
            }
        }

        private void bind(uint keycode, uint modMask,
            string action_name, GLib.Variant? parameter) {
            this.bindKeyOrMouse(false, keycode, modMask,
                action_name, parameter);
        }

        private void bindMouse(uint keycode, uint modMask,
            string action_name, GLib.Variant? parameter) {
            this.bindKeyOrMouse(true, keycode, modMask,
                action_name, parameter);
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
         * This separate handling is needed because keypresses from any of the
         * window have implications on the behaviour of both of them. Therefore
         * this controller is needed to take care of the needed actions.
         */
        public bool key_press(Gdk.EventKey key) {
            if (key.time != last_key_event && !ignore_keyboard_events ) {
                last_key_event = key.time;
                if (this.overview_shown && this.overview.key_press_event(key))
                    return true;

                // Punctuation characters are usually generated by keyboards
                // with the Shift mod pressed; we ignore it in this case.
                if (((char) key.keyval).ispunct()) {
                    key.state &= ~Gdk.ModifierType.SHIFT_MASK;
                }
                var action_with_parameter = this.keyBindings.get(new KeyDef(key.keyval,
                    key.state & this.accepted_key_mods));

                if (action_with_parameter != null)
                    action_with_parameter.action.activate(action_with_parameter.parameter);
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
                var action_with_parameter = this.mouseBindings.get(new KeyDef(button.button,
                    button.state & this.accepted_key_mods));
                if (action_with_parameter != null)
                    action_with_parameter.action.activate(action_with_parameter.parameter);
                return true;
            } else {
                return false;
            }
        }

        /**
         * Notify each of the controllables of mouse scrolling
         */
        public bool scroll(Gdk.EventScroll scroll) {
            if (!this.ignore_mouse_events && !Options.disable_scrolling) {
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
         * Set the last slide as defined by the user
         */
        private void set_end_user_slide() {
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
            if(this.current_slide_number > this.user_slide_progress[this.current_user_slide_number]) {
                this.user_slide_progress[this.current_user_slide_number] = this.current_slide_number;
            }
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
                    if (bt.actionArg != null) {
                        bind(bt.keyCode, bt.modMask, bt.actionName, new GLib.Variant.string(bt.actionArg));
                    } else {
                        bind(bt.keyCode, bt.modMask, bt.actionName, null);
                    }
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
                    if (bt.actionArg != null) {
                        bindMouse(bt.keyCode, bt.modMask, bt.actionName, new GLib.Variant.string(bt.actionArg));
                    } else {
                        bindMouse(bt.keyCode, bt.modMask, bt.actionName, null);
                    }
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

            this.controllables.add(controllable);

            return true;
        }

        /**
         * Go to the next slide
         */
        public void next_page() {
            if (!this.metadata.is_ready) {
                return;
            }
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
            } else if (Options.black_on_end && !this.faded_to_black) {
                this.fade_to_black();
            }
            if(this.current_slide_number > this.user_slide_progress[this.current_user_slide_number]) {
                this.user_slide_progress[this.current_user_slide_number] = this.current_slide_number;
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
                if (this.current_slide_number + 1 == this.n_slides) {
                    if (Options.black_on_end && !this.faded_to_black) {
                        this.fade_to_black();
                    }
                } else {
                    // move to the last slide, we are already at the last user slide
                    if (this.n_slides > 0) {
                        this.current_slide_number = (int) this.n_slides - 1;
                    }
                }
            }

            if (needs_update) {
                if (!this.frozen) {
                    this.faded_to_black = false;
                }
                this.controllables_update();
            }

            if(this.current_slide_number > this.user_slide_progress[this.current_user_slide_number]) {
                this.user_slide_progress[this.current_user_slide_number] = this.current_slide_number;
            }
        }

        /**
         * Go to next real slide of the current user slide if there is one
         * otherwise go to largest already seen real slide on next user slide
         */
        public void next_unseen() {
            this.timer.start();

            if (!this.frozen) {
                this.faded_to_black = false;
            }

            if(this.current_slide_number + 1 == this.n_slides) {
                return;
            }

            int next_slide = this.current_slide_number + 1;
            if(next_slide < this.n_slides - 1) {
                int user_slide_at_next_slide = this.metadata.real_slide_to_user_slide(next_slide);
                if(this.user_slide_progress[user_slide_at_next_slide] != 0 &&
                        this.user_slide_progress[user_slide_at_next_slide] >= next_slide) {
                    next_slide = this.user_slide_progress[user_slide_at_next_slide];
                }
            }

            this.current_slide_number = next_slide;
            this.current_user_slide_number = this.metadata.real_slide_to_user_slide(this.current_slide_number);
            if(this.current_slide_number > this.user_slide_progress[this.current_user_slide_number]) {
                this.user_slide_progress[this.current_user_slide_number] = this.current_slide_number;
            }

            this.controllables_update();
        }

        /**
         * Jump to the last overlay for the current user slide
         */
        public void jump_to_last_overlay() {
            this.timer.start();

            int destination = this.metadata.user_slide_to_real_slide(this.current_user_slide_number, true);
            if (this.current_slide_number != destination) {
                this.current_slide_number = destination;

                if (!this.frozen) {
                    this.faded_to_black = false;
                }
                this.controllables_update();

                if(this.current_slide_number > this.user_slide_progress[this.current_user_slide_number]) {
                    this.user_slide_progress[this.current_user_slide_number] = this.current_slide_number;
                }
            }
        }

        /**
         * Jump to the first overlay for the current user slide
         */
        public void jump_to_first_overlay() {
            this.timer.start();

            int destination = this.metadata.user_slide_to_real_slide(this.current_user_slide_number, false);
            if (this.current_slide_number != destination) {
                this.current_slide_number = destination;

                if (!this.frozen) {
                    this.faded_to_black = false;
                }
                this.controllables_update();

                if(this.current_slide_number > this.user_slide_progress[this.current_user_slide_number]) {
                    this.user_slide_progress[this.current_user_slide_number] = this.current_slide_number;
                }
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

                if(this.current_slide_number > this.user_slide_progress[this.current_user_slide_number]) {
                    this.user_slide_progress[this.current_user_slide_number] = this.current_slide_number;
                }
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

            if(this.current_slide_number > this.user_slide_progress[this.current_user_slide_number]) {
                this.user_slide_progress[this.current_user_slide_number] = this.current_slide_number;
            }
        }

        /**
         * Go to the largest already seen real slide on previous user slide
         */
        public void previous_seen() {
            this.timer.start();

            if (!this.frozen) {
                this.faded_to_black = false;
            }

            if(this.current_slide_number == 0) {
                return;
            }
            this.current_slide_number = this.user_slide_progress[this.current_user_slide_number-1];
            this.current_user_slide_number = this.metadata.real_slide_to_user_slide(this.current_slide_number);

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
         * Go to the named slide
         */
        public void goto_string(Variant? page) {
            this.timer.start();

            int destination = int.parse(page.get_string()) - 1;
            this.goto_user_page(destination);

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
         * Goto a slide in user page numbers
         */
        public void goto_user_page(int page_number, bool useLast = true) {
            this.timer.start();

            if (this.current_user_slide_number != page_number) {
                this.push_history();
            }

            this.controllables_hide_overview();
            int destination = page_number;
            int n_user_slides = this.metadata.get_user_slide_count();
            if (page_number < 0) {
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

        protected void toggle_overview() {
            if (!this.metadata.is_ready) {
                return;
            }
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

        public void controllables_hide_overview() {
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

        protected void toggle_windowed() {
            if (this.presenter != null) {
                this.presenter.toggle_windowed();
            } else if (this.presentation != null) {
                this.presentation.toggle_windowed();
            }
        }

        /**
         * Fill the presentation display with black
         */
        public void fade_to_black() {
            if (this.single_screen_mode) {
                return;
            }

            this.faded_to_black = !this.faded_to_black;
            this.controllables_update();
        }

        /**
         * Hide the presentation window
         */
        public void hide_presentation() {
            if (this.single_screen_mode) {
                return;
            }

            this.hidden = !this.hidden;
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
         * Freeze the presentation window
         */
        public void toggle_freeze() {
            if (this.single_screen_mode) {
                return;
            }

            this.frozen = !this.frozen;
            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
            this.presentation.main_view.freeze_toggled(this.frozen);
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
        public void toggle_pause() {
            this.timer.pause();
            this.controllables_update();
        }

        /**
         * Reset the timer
         */
        protected void reset_timer() {
            this.timer.reset();
        }

        /**
         * Reload the presentation
         */
        protected void reload() {
            var fname = this.metadata.pdf_fname;
            if (fname != null) {
                if (this.overview_shown) {
                    this.controllables_hide_overview();
                }

                var position_saved = this.current_slide_number;
                this.metadata.load(fname);
                if (this.n_slides == 0) {
                    return;
                }

                // Make sure the current position remains valid
                if (position_saved >= this.n_slides) {
                    this.current_slide_number = (int) this.n_slides - 1;
                    this.current_user_slide_number =
                        this.metadata.real_slide_to_user_slide(
                            this.current_slide_number);
                }

                // Reset the drawing storage & clear the current drawings
                this.pen_drawing.clear_storage();
                this.clear_pen_drawing();

                this.overview.set_n_slides(this.user_n_slides);
                this.cache_status.reset();
                this.reload_request();
                this.controllables_update();
            }
        }

        protected void increase_font_size() {
            this.increase_font_size_request();
        }

        protected void decrease_font_size() {
            this.decrease_font_size_request();
        }

        /**
         * Mode-sensitive size increment
         */
        protected void increase_size() {
            switch (this.annotation_mode) {
                case AnnotationMode.NORMAL:
                this.increase_font_size();
                break;

                case AnnotationMode.POINTER:
                this.increase_pointer_size();
                break;

                case AnnotationMode.PEN:
                case AnnotationMode.ERASER:
                this.increase_pen_size();
                break;
            }
        }

        /**
         * Mode-sensitive size decrement
         */
        protected void decrease_size() {
            switch (this.annotation_mode) {
                case AnnotationMode.NORMAL:
                this.decrease_font_size();
                break;

                case AnnotationMode.POINTER:
                this.decrease_pointer_size();
                break;

                case AnnotationMode.PEN:
                case AnnotationMode.ERASER:
                this.decrease_pen_size();
                break;
            }
        }

        /**
         * Toggle toolbox visibility
         */
        public void toggle_toolbox() {
            Options.toolbox_shown = !Options.toolbox_shown;
            this.controllables_update();
        }

        public void show_help() {
            if (this.presenter != null) {
                this.presenter.show_help_window(true);
            }
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


#if MOVIES
        /**
         * Give the Gdk.Rectangle corresponding to the Poppler.Rectangle for the nth
         * controllable's main view.
         */
        public void overlay_pos(int n, Poppler.Rectangle area, out Gdk.Rectangle rect, out Window.Fullscreen window) {
            window = null;

            Controllable c = (n < this.controllables.size) ? this.controllables.get(n) : null;
            // default scale, and make the compiler happy
            if (c == null) {
                rect = Gdk.Rectangle();
                return;
            }
            window = c as Window.Fullscreen;
            if (c.main_view == null) {
                rect = Gdk.Rectangle();
                return;
            }
            rect = c.main_view.convert_poppler_rectangle_to_gdk_rectangle(area);
        }
#endif
    }
}
