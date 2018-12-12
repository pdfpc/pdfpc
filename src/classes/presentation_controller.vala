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
                    presenter.current_view.size_allocate.connect(init_presenter_pen_and_pointer);
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
                    presentation.main_view.size_allocate.connect(init_presentation_pen_and_pointer);
                }
            }
        }
        private Window.Presentation _presentation=null;
        public Gtk.Image presenter_pointer;
        public Gtk.Image presentation_pointer;

        public Gtk.DrawingArea? presenter_pointer_surface;
        public Gtk.DrawingArea? presentation_pointer_surface;

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

            public ActionAndParameter(GLib.Action action, GLib.Variant? parameter) {
                this.action = action;
                this.parameter = parameter;
            }
        }

        protected Gee.HashMap<KeyDef, ActionAndParameter> keyBindings = new Gee.HashMap<KeyDef, ActionAndParameter>();
        // We abuse the KeyDef structure
        protected Gee.HashMap<KeyDef, ActionAndParameter> mouseBindings = new Gee.HashMap<KeyDef, ActionAndParameter>();

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
        public PresentationController(Metadata.Pdf metadata, bool allow_black_on_end) {
            this.metadata = metadata;
            this.metadata.controller = this;
            this.black_on_end = allow_black_on_end;

            this.controllables = new Gee.ArrayList<Controllable>();

            this.history = new Gee.ArrayQueue<int>();
            this.user_slide_progress = new int[metadata.get_user_slide_count()];

            // If end_time is set, reset duration to 0
            if (Options.end_time != null) {
                Options.duration = 0;
                this.metadata.set_duration(0);
            }
            this.timer = getTimerLabel(this,
                (int) this.metadata.get_duration() * 60);
            this.timer.reset();

            this.n_slides = (int) this.metadata.get_slide_count();

            this.current_slide_number = 0;
            this.current_user_slide_number = 0;

            this.add_actions();

            Bus.get_proxy.begin<ScreenSaver>(BusType.SESSION, "org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver", 0, null, (obj, res) => {
                try {
                    this.screensaver = Bus.get_proxy.end(res);
                    this.screensaver.inhibit.begin("pdfpc", "Showing a presentation", (obj, res) => {
                        try {
                            this.screensaver_cookie = this.screensaver.inhibit.end(res);
                            GLib.print("Screensaver inhibited\n");
                        } catch (GLib.Error error) {
                            // pass
                        }
                    });
                } catch (GLib.Error error) {
                    // pass
                }
            });

            readKeyBindings();
            readMouseBindings();


            DBusServer.start_server(this, this.metadata);
        }

        /* pen drawing widgets */
        public Gtk.DrawingArea? presenter_pen_surface;
        public Gtk.DrawingArea? presentation_pen_surface;

        public Drawings.Drawing pen_drawing;
        private Drawings.DrawingTool? current_pen_drawing_tool = null;

        /* pen drawing state */
        private bool pen_drawing_present = false;

        private uint pen_step = 2;
        private double pen_last_x;
        private double pen_last_y;
        private bool pen_is_pressed = false;

        protected void init_pen_drawing_if_needed(Gtk.Allocation a) {
            if (this.pen_drawing == null) {
                this.pen_drawing = Drawings.create(metadata,
                                                   a.width,
                                                   a.height);
                current_pen_drawing_tool = pen_drawing.pen;
            }
        }

        protected void init_presentation_pen() {
            init_pen_drawing_if_needed(presentation_allocation);
            this.presentation_pen_surface = presentation.pen_drawing_surface;
            this.presentation_pen_surface.hide();
            this.presentation_pen_surface.draw.connect ((context) => {
                draw_pen_surface(context, presentation_allocation, false);
                return true;
            });
        }

        protected void init_presenter_pen() {
            init_pen_drawing_if_needed(presenter_allocation);
            this.presenter_pen_surface = presenter.pen_drawing_surface;
            this.presenter_pen_surface.hide();

            this.presenter_pen_surface.set_events(
                  Gdk.EventMask.BUTTON_PRESS_MASK
                | Gdk.EventMask.BUTTON_RELEASE_MASK
                | Gdk.EventMask.POINTER_MOTION_MASK
            );

            this.presenter_pen_surface.draw.connect ((context) => {
                draw_pen_surface(context, presenter_allocation, true);
                return true;
            });

            this.presenter_pen_surface.button_press_event.connect((event) => {
                if (in_drawing_mode()) {
                    move_pen(
                        event.x / presenter_allocation.width,
                        event.y / presenter_allocation.height
                    );
                    pen_is_pressed = true;
                    return true;
                } else {
                    return false;
                }
            });

            this.presenter_pen_surface.button_release_event.connect((event) => {
                if (in_drawing_mode()) {
                    move_pen(
                        event.x / presenter_allocation.width,
                        event.y / presenter_allocation.height
                    );
                    pen_is_pressed = false;
                    return true;
                } else {
                    return false;
                }
            });

            this.presenter_pen_surface.motion_notify_event.connect(on_move_pen);

            this.update_request.connect(this.update_pen_drawing);
        }

        public bool is_eraser_active() {
            return annotation_mode == AnnotationMode.ERASER;
        }

        public bool is_pen_active() {
            return annotation_mode == AnnotationMode.PEN;
        }

        protected bool in_drawing_mode() {
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
                presenter_pen_surface.queue_draw();
            }
            if (presentation != null) {
                presentation_pen_surface.queue_draw();
            }
        }

        protected void update_pen_drawing() {
            pen_drawing.switch_to_slide(
                this.metadata.user_slide_to_real_slide(this.current_user_slide_number)
            );
            this.queue_pen_surface_draws();
        }

        protected bool on_move_pen(Gtk.Widget source, Gdk.EventMotion move) {
            if (!Options.disable_input_autodetection) {
                Gdk.InputSource source_type =
                    move.get_source_device().get_source();
                if (source_type == Gdk.InputSource.ERASER) {
                    this.set_mode(AnnotationMode.ERASER);
                } else if (source_type == Gdk.InputSource.PEN) {
                    this.set_mode(AnnotationMode.PEN);
                }
            }

            if (in_drawing_mode()) {
                move_pen(move.x/presenter_allocation.width,
                         move.y/presenter_allocation.height);
            }
            return true;
        }

        protected void draw_pen_surface(Cairo.Context context, Gtk.Allocation a, bool for_presenter) {
            if (pen_drawing != null) {
                Cairo.Surface? drawing_surface = pen_drawing.render_to_surface();
                int x = (int)(a.width*pen_last_x);
                int y = (int)(a.height*pen_last_y);
                int base_width = pen_drawing.width;
                int base_height = pen_drawing.height;
                Cairo.Matrix old_xform = context.get_matrix();
                context.scale(
                    (double) a.width / base_width,
                    (double) a.height / base_height
                );
                context.set_source_surface(drawing_surface, 0, 0);
                context.paint();
                context.set_matrix(old_xform);
                if (for_presenter && in_drawing_mode()) {
                    double width_adjustment = (double) a.width / base_width;
                    context.set_operator(Cairo.Operator.OVER);
                    context.set_line_width(2.0);
                    context.set_source_rgba(
                        current_pen_drawing_tool.red,
                        current_pen_drawing_tool.green,
                        current_pen_drawing_tool.blue,
                        1.0
                    );
                    double arc_radius = current_pen_drawing_tool.width * width_adjustment / 2.0;
                    if (arc_radius < 1.0) {
                        arc_radius = 1.0;
                    }
                    context.arc(x, y, arc_radius, 0, 2*Math.PI);
                    context.stroke();
                }
            }
        }

        private void hide_or_show_pen_surfaces() {
            if (pen_drawing_present) {
                if (presenter != null) {
                    presenter_pen_surface.show();
                }
                if (presentation != null) {
                    presentation_pen_surface.show();
                }
                queue_pen_surface_draws();
            } else {
                if (presenter != null) {
                    presenter_pen_surface.hide();
                }
                if (presentation != null) {
                    presentation_pen_surface.hide();
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
            if (this.annotation_mode == AnnotationMode.POINTER) {
                if (presenter != null) {
                    presenter_pointer_surface.show();
                }
                if (presentation != null) {
                    presentation_pointer_surface.show();
                }
            } else {
                if (presenter != null) {
                    presenter_pointer_surface.hide();
                }
                if (presentation != null) {
                    presentation_pointer_surface.hide();
                }
            }

            // Update drawing surfaces
            hide_or_show_pen_surfaces();

            if (this.presenter != null) {
                // Disable event compression for smoother drawing
                this.presenter.get_window().set_event_compression(!in_drawing_mode());

                // When drawing mode is inactive, make the drawing surface
                // transparent to the input events
                var w = presenter_pen_surface.get_window();
                if (w != null) {
                    w.set_pass_through(!in_drawing_mode());
                }
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


        private Gtk.Allocation presenter_allocation;
        private Gtk.Allocation presentation_allocation;

        private void init_presentation_pen_and_pointer(Gtk.Allocation a) {
            presentation_allocation = a;
            init_presentation_pen();
            init_presentation_pointer();
        }

        private void init_presenter_pen_and_pointer(Gtk.Allocation a) {
            presenter_allocation = a;
            init_presenter_pen();
            init_presenter_pointer();
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
        }

        private uint pointer_size;
        private uint pointer_step = 5;
        private Gdk.RGBA pointer_color;

        private double highlight_x;
        private double highlight_y;
        private double highlight_w;
        private double highlight_h;
        private double drag_x;
        private double drag_y;
        private double pointer_x;
        private double pointer_y;

        public bool is_pointer_active() {
            return this.annotation_mode == AnnotationMode.POINTER;
        }

        protected void init_presenter_pointer() {
            this.presenter_pointer_surface = presenter.pointer_drawing_surface;
            this.presenter_pointer_surface.hide();

            this.presenter_pointer_surface.draw.connect ((context) => {
                draw_pointer(context, presenter_allocation);
                return true;
            });

            drag_x=-1;
            drag_y=-1;
            this.presenter_pointer_surface.button_press_event.connect((event) => {
                drag_x=event.x/presenter_allocation.width;
                drag_y=event.y/presenter_allocation.height;
                highlight_w=0;
                highlight_h=0;

                return true;
            });
            this.presenter_pointer_surface.button_release_event.connect((event) => {
                update_highlight(event.x/presenter_allocation.width, event.y/presenter_allocation.height);
                drag_x=-1;
                drag_y=-1;

                return true;
            });

            this.presenter_pointer_surface.motion_notify_event.connect(on_move_pointer);

            this.presenter_pointer_surface.set_events(
                  Gdk.EventMask.BUTTON_PRESS_MASK
                | Gdk.EventMask.BUTTON_RELEASE_MASK
                | Gdk.EventMask.POINTER_MOTION_MASK
            );

            var w = presenter_pointer_surface.get_window();
            if (w != null) {
                w.set_cursor(new Gdk.Cursor.from_name(Gdk.Display.get_default(), "none"));
            }
        }

        protected void init_presentation_pointer() {
            this.presentation_pointer_surface = presentation.pointer_drawing_surface;
            this.presentation_pointer_surface.hide();

            this.presentation_pointer_surface.draw.connect ((context) => {
                draw_pointer(context, presentation_allocation);
                return true;
            });
        }

        private void queue_pointer_surface_draws() {
            if (presenter != null) {
                presenter_pointer_surface.queue_draw();
            }
            if (presentation != null) {
                presentation_pointer_surface.queue_draw();
            }
        }

        public void move_pointer(double percent_x, double percent_y) {
            pointer_y = percent_y;
            pointer_x = percent_x;
            if (presenter != null) {
                presenter_pointer_surface.queue_draw();
            }
            if (presentation != null) {
                presentation_pointer_surface.queue_draw();
            }
        }

        /**
         * Handle mouse scrolling events on the window and, if neccessary send
         * them to the presentation controller
         */
        protected bool on_move_pointer(Gtk.Widget source, Gdk.EventMotion move) {
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
                queue_pointer_surface_draws();
            }
        }

        protected void draw_pointer(Cairo.Context context, Gtk.Allocation a) {
            // Draw the highlighted area, but ignore very short drags
            // made unintentionally by mouse clicks
            if (highlight_w > 0.01 && highlight_h > 0.01) {
                context.rectangle(0,0,a.width, a.height);
                context.new_sub_path();
                context.rectangle((int)(highlight_x*a.width), (int)(highlight_y*a.height), (int)(highlight_w*a.width), (int)(highlight_h*a.height));

                context.set_fill_rule (Cairo.FillRule.EVEN_ODD);
                context.set_source_rgba(0,0,0,0.5);
                context.fill_preserve();

                context.new_path();
            }
            // Draw the pointer when not dragging
            if (drag_x == -1) {
                int x = (int)(a.width*pointer_x);
                int y = (int)(a.height*pointer_y);
                int r = (int)(a.height*0.001*pointer_size);

                context.set_source_rgba(pointer_color.red,
                                        pointer_color.green,
                                        pointer_color.blue,
                                        pointer_color.alpha);
                context.arc(x, y, r, 0, 2*Math.PI);
                context.fill();
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
            add_action_with_parameter("switchMode", GLib.VariantType.STRING,
                this.set_mode_to_string);
            add_action("clearDrawing", this.clear_pen_drawing);
            add_action("toggleDrawings", this.toggle_drawings);

            add_action_with_parameter("setPenColor", GLib.VariantType.STRING,
                this.set_pen_color_to_string);

            add_action("next", this.next_page);
            add_action("next10", this.jump10);
            add_action("lastOverlay", this.jump_to_last_overlay);
            add_action("nextOverlay", this.next_user_page);
            add_action("prev", this.previous_page);
            add_action("prev10", this.back10);
            add_action("firstOverlay", this.jump_to_first_overlay);
            add_action("prevOverlay", this.previous_user_page);
            add_action("prevSeen", this.previous_seen);
            add_action("nextUnseen", this.next_unseen);

            add_action("goto", this.controllables_ask_goto_page);
            add_action("gotoFirst", this.goto_first);
            add_action("gotoLast", this.goto_last);
            add_action("overview", this.toggle_overview);
            add_action("histBack", this.history_back);

            add_action("start", this.start);
            add_action("pause", this.toggle_pause);
            add_action("resetTimer", this.reset_timer);

            add_action("blank", this.fade_to_black);
            add_action("freeze", this.toggle_freeze);
            add_action("freezeOn", () => {
                if (!this.frozen)
                    this.toggle_freeze();
                });
            add_action("hide", this.hide_presentation);

            add_action("overlay", this.toggle_skip);
            add_action("note", this.controllables_edit_note);
            add_action("endSlide", this.set_end_user_slide);
            add_action("saveBookmark", this.set_last_saved_slide);
            add_action("loadBookmark", this.goto_last_saved_slide);

            add_action("increaseSize", this.increase_size);
            add_action("decreaseSize", this.decrease_size);

            add_action("toggleToolbox", this.toggle_toolbox);

            add_action("exitState", this.exit_state);
            add_action("quit", this.quit);
        }

        protected void add_action(string name, callback func) {
            SimpleAction action = new SimpleAction(name, null);
            action.activate.connect(() => func());  // Trying to connect func directly causes error.
            this.action_group.add_action(action);
        }

        protected void add_action_with_parameter(string name, GLib.VariantType param_type, callback_with_parameter func) {
            SimpleAction action = new SimpleAction(name, param_type);
            action.activate.connect((param) => func(param));
            this.action_group.add_action(action);
        }

        /**
         * Get an array with all action names
         *
         * It would be more elegant to use the key property of actionNames, but
         * we would need an instance for doing this...
         */
        public static string[] getActionDescriptions() {
            return {
                "next", "Go to the next slide",
                "next10", "Jump 10 slides forward",
                "lastOverlay", "Jump to the last overlay of the current slide",
                "nextOverlay", "Jump forward outside of the current overlay",
                "prev", "Go to the previous slide",
                "prev10", "Jump 10 slides back",
                "firstOverlay", "Jump to the first overlay of the current slide",
                "prevOverlay", "Jump back outside of the current overlay",
                "goto", "Ask for a page to jump to",
                "gotoFirst", "Jump to the first slide",
                "gotoLast", "Jump to the last slide",
                "nextUnseen", "Jump to the next unseen slide",
                "prevSeen", "Jump to the last previously seen slide",
                "overview", "Show the overview mode",
                "histBack", "Go back in history",
                "start", "Start the timer",
                "pause", "Pause the timer",
                "resetTimer", "Reset the timer",
                "blank", "Blank the presentation screen",
                "hide", "Hide the presentation screen",
                "freeze", "Toggle freeze the presentation screen",
                "freezeOn", "Freeze the presentation screen",
                "overlay", "Mark the current slide as an overlay slide",
                "note", "Edit notes for the current slide",
                "endSlide", "Set the current slide as the end slide",
                "saveBookmark", "Bookmark the currently displayed slide",
                "loadBookmark", "Load the bookmarked slide",
                "switchMode <mode>", "Switch annotation mode (normal|pointer|pen|eraser)",
                "increaseSize", "Increase the size of notes|pointer|pen|eraser",
                "decreaseSize", "Decrease the size of notes|pointer|pen|eraser",
                "setPenColor <color>", "Change the pen color",
                "clearDrawing", "Clear drawing on the current slide",
                "toggleDrawings", "Toggle all drawings on all slides",
                "toggleToolbox", "Toggle the toolbox",
                "exitState", "Exit \"special\" state (pause, freeze, blank)",
                "quit", "Exit pdfpc",
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
        public void bind(uint keycode, uint modMask, string action_name, GLib.Variant? parameter) {
            Action? action = this.action_group.lookup_action(action_name);
            if (action != null) {
                GLib.VariantType expected_type = action.get_parameter_type();
                if (expected_type == null) {
                    if (parameter != null) {
                        GLib.printerr("Parameter provided to action %s that does not expect one\n", action_name);
                    }
                } else if (parameter == null) {
                    GLib.printerr("Parameter expected for action %s but not provided\n", action_name);
                } else {
                    assert(
                        parameter.get_type().equal(GLib.VariantType.STRING) &&
                        expected_type.equal(GLib.VariantType.STRING)
                    );
                }
                this.keyBindings.set(new KeyDef(keycode, modMask),
                    new ActionAndParameter(action, parameter));
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
        public void bindMouse(uint button, uint modMask, string action_name, Variant? parameter) {
            Action? action = this.action_group.lookup_action(action_name);
            if (action != null) {
                GLib.VariantType expected_type = action.get_parameter_type();
                if (expected_type == null) {
                    if (parameter != null) {
                        GLib.printerr("Parameter provided to action %s that does not expect one\n", action_name);
                    }
                } else if (parameter == null) {
                    GLib.printerr("Parameter expected for action %s but not provided\n", action_name);
                } else {
                    assert(
                        parameter.get_type().equal(GLib.VariantType.STRING) &&
                        expected_type.equal(GLib.VariantType.STRING)
                    );
                }
                this.mouseBindings.set(new KeyDef(button, modMask),
                    new ActionAndParameter(action, parameter));
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
         * This separate handling is needed because keypresses from any of the
         * window have implications on the behaviour of both of them. Therefore
         * this controller is needed to take care of the needed actions.
         */
        public bool key_press(Gdk.EventKey key) {
            if (key.time != last_key_event && !ignore_keyboard_events ) {
                last_key_event = key.time;
                if (this.overview_shown && this.overview.key_press_event(key))
                    return true;

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

            if(this.current_slide_number == this.n_slides - 1) {
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
        public void fade_to_black() {
            this.faded_to_black = !this.faded_to_black;
            this.controllables_update();
        }

        /**
         * Hide the presentation window
         */
        public void hide_presentation() {
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
         * Freeze the display
         */
        public void toggle_freeze() {
            this.frozen = !this.frozen;
            if (!this.frozen) {
                this.faded_to_black = false;
            }
            this.controllables_update();
            main_view.freeze_toggled(this.frozen);
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
        public void overlay_pos(int n, Poppler.Rectangle area, out Gdk.Rectangle rect, out int gdk_scale, out Window.Fullscreen window) {
            window = null;

            Controllable c = (n < this.controllables.size) ? this.controllables.get(n) : null;
            // default scale, and make the compiler happy
            gdk_scale = 1;
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
            gdk_scale = c.main_view.scale_factor;
        }
#endif
    }
}
