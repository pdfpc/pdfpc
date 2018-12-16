/**
 * Main application file
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
 * Copyright 2012, 2015-2017 Andreas Bilke
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2014-2015 Andy Barry
 * Copyright 2015 Maurizio Tomasi
 * Copyright 2015 Jeremy Maitin-Shepard
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

namespace pdfpc {
    /**
     * Pdf Presenter Console main application class
     *
     * This class contains the main method as well as all the logic needed for
     * initializing the application, like commandline parsing and window creation.
     */
    public class Application: GLib.Object {

        /**
         * PresentationController instanace managing all actions which need to
         * be coordinated between the different windows
         */
        private PresentationController controller;

        /**
         * CacheStatus widget, which coordinates all the information about
         * cached slides to provide a visual feedback to the user about the
         * rendering state
         */
        private CacheStatus cache_status;

        /**
         * Commandline option parser entry definitions
         */
        const OptionEntry[] options = {
            {"disable-cache", 'c', 0, 0,
                ref Options.disable_caching,
                "Disable caching and pre-rendering of slides", null},
            {"time-of-day", 'C', 0, 0,
                ref Options.use_time_of_day,
                "Use the current time for the timer", null},
            {"duration", 'd', 0, OptionArg.INT,
                ref Options.duration,
                "Duration of the presentation (in minutes)", "N"},
            {"end-time", 'e', 0, OptionArg.STRING,
                ref Options.end_time,
                "End time of the presentation", "HH:MM"},
            {"disable-auto-grouping", 'g', 0, 0,
                ref Options.disable_auto_grouping,
                "Disable auto detection of overlays", null},
            {"last-minutes", 'l', 0, OptionArg.INT,
                ref Options.last_minutes,
                "Change the timer color during last N mins [5]", "N"},
            {"list-actions", 'L', 0, 0,
                ref Options.list_actions,
                "List actions supported in the config file(s)", null},
            {"list-monitors", 'M', 0, 0,
                ref Options.list_monitors,
                "List available monitors", null},
            {"notes", 'n', 0, OptionArg.STRING,
                ref Options.notes_position,
                "Position of notes (left|right|top|bottom)", "P"},
            {"no-install", 'N', 0, 0,
                ref Options.no_install,
                "Test pdfpc without installation", null},
            {"persist-cache", 'p', 0, 0,
                ref Options.persist_cache,
                "Keep the cache on disk for faster startup", null},
            {"page", 'P', 0, OptionArg.INT,
                ref Options.page,
                "Go to page number N directly after startup", "N"},
            {"pdfpc-location", 'R', 0, OptionArg.STRING,
                ref Options.pdfpc_location,
                "Full path location to a pdfpc file", "PATH"},
            {"switch-screens", 's', 0, 0,
                ref Options.display_switch,
                "Swap the presentation/presenter screens", null},
            {"single-screen", 'S', 0, 0,
                ref Options.single_screen,
                "Force to use only one screen", null},
            {"start-time", 't', 0, OptionArg.STRING,
                ref Options.start_time,
                "Start time of the presentation", "HH:MM"},
            {"enable-auto-srt-load", 'T', 0, 0,
                ref Options.auto_srt,
                "Load video subtitle files automatically", null},
            {"version", 'v', 0, 0,
                ref Options.version,
                "Output version information and exit", null},
            {"windowed", 'w', 0, 0,
                ref Options.windowed,
                "Run in the windowed mode", null},
            {"wayland-workaround", 'W', 0, 0,
                ref Options.wayland_workaround,
                "Enable Wayland-specific workaround", null},
            {"disable-compression", 'z', 0, 0,
                ref Options.disable_cache_compression,
                "Disable compression of the cached slide images", null},
            {"size", 'Z', 0, OptionArg.STRING,
                ref Options.size,
                "Size of the presentation window (implies \"-w\")", "W:H"},
            {"presenter-screen", '1', 0, OptionArg.STRING,
                ref Options.presenter_screen,
                "Monitor to be used for the presenter", "M"},
            {"presentation-screen", '2', 0, OptionArg.STRING,
                ref Options.presentation_screen,
                "Monitor to be used for the presentation", "M"},
            {null}
        };

        /**
         * Parse the commandline and apply all found options to there according
         * static class members.
         *
         * Returns the name of the pdf file to open (or null if not present)
         */
        protected string? parse_command_line_options(ref unowned string[] args) {
            // intialize Options for the first time to invoke static construct
            new Options();

            var context = new OptionContext("<pdf-file>");
            context.add_main_entries(options, null);

            try {
                context.parse(ref args);
            } catch(OptionError e) {
                GLib.printerr("%s\n\n%s\n", e.message, context.get_help(true, null));
                Process.exit(1);
            }
            if (args.length < 2) {
                return null;
            } else {
                return args[1];
            }
        }

        /**
         * Print version string and copyright statement
         */
        private void print_version() {
            GLib.print("pdfpc v4.3.0\n"
                     + "Copyright (C) 2010-2018 see CONTRIBUTORS\n\n"
                     + "License GPLv2: GNU GPL version 2 <http://gnu.org/licenses/gpl-2.0.html>.\n"
                     + "This is free software: you are free to change and redistribute it.\n"
                     + "There is NO WARRANTY, to the extent permitted by law.\n");
        }

        /**
         * Set the CSS styling for GTK.
         */
        private void set_styling() {
            var globalProvider = new Gtk.CssProvider();
            var userProvider = new Gtk.CssProvider();

            Gtk.StyleContext.add_provider_for_screen(Gdk.Display.get_default().get_default_screen(),
                globalProvider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            Gtk.StyleContext.add_provider_for_screen(Gdk.Display.get_default().get_default_screen(),
                userProvider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

            string distCssPath;
            if (Options.no_install) {
                distCssPath = Path.build_filename(Paths.SOURCE_PATH, "rc/pdfpc.css");
            } else {
                distCssPath = Path.build_filename(Paths.ICON_PATH, "pdfpc.css");
            }
            var legacyUserCssPath = Path.build_filename(GLib.Environment.get_user_config_dir(), "pdfpc.css");
            var userCssPath = Path.build_filename(GLib.Environment.get_user_config_dir(), "pdfpc", "pdfpc.css");

            try {
                // pdfpc.css in dist path is mandatory
                if (GLib.FileUtils.test(distCssPath, (GLib.FileTest.IS_REGULAR))) {
                    globalProvider.load_from_path(distCssPath);
                } else {
                    GLib.printerr("No CSS file found\n");
                    Process.exit(1);
                }
                // load custom user css on top
                if (GLib.FileUtils.test(userCssPath, (GLib.FileTest.IS_REGULAR))) {
                    userProvider.load_from_path(userCssPath);
                } else if (GLib.FileUtils.test(legacyUserCssPath, (GLib.FileTest.IS_REGULAR))) {
                    userProvider.load_from_path(legacyUserCssPath);
                    GLib.printerr("Loaded pdfpc.css from legacy location. Please move your style sheet to %s\n", userCssPath);
                }
            } catch (Error error) {
                GLib.printerr("Could not load styling from data: %s\n", error.message);
            }
        }

        /**
         * Create and return a PresenterWindow using the specified monitor
         * while displaying the given file
         */
        private Window.Presenter create_presenter(Metadata.Pdf metadata, int monitor) {
            var presenter = new Window.Presenter(metadata, monitor, this.controller);
            presenter.set_cache_observer(this.cache_status);

            return presenter;
        }

        /**
         * Create and return a PresentationWindow using the specified monitor
         * while displaying the given file
         */
        private Window.Presentation create_presentation(Metadata.Pdf metadata, int monitor, int width = -1, int height = -1) {
            var presentation = new Window.Presentation(metadata, monitor, this.controller, width, height);
            presentation.set_cache_observer(this.cache_status);

            return presentation;
        }

        /**
         * Main application function, which instantiates the windows and
         * initializes the Gtk system.
         */
        public void run(string[] args) {
#if X11
            X.init_threads();
#endif
            Gtk.init(ref args);

            var display = Gdk.Display.get_default();

            string pdfFilename = this.parse_command_line_options(ref args);

            if (Options.version) {
                print_version();
                Process.exit(0);
            }

            if (Options.list_monitors) {
                int n_monitors = display.get_n_monitors();
                GLib.print("Monitors: %d\n", n_monitors);
                for (int i = 0; i < n_monitors; i++) {
                    var monitor = display.get_monitor(i);
                    int sf = monitor.get_scale_factor();
                    var geo = monitor.get_geometry();
                    GLib.print(" %d: %c %s \t[%dx%d+%d+%d@%dHz \tscale=%d%%]\n",
                        i, monitor.is_primary() ? '*':' ',
                        monitor.get_model(),
                        geo.width*sf, geo.height*sf,
                        geo.x*sf, geo.y*sf,
                        (monitor.get_refresh_rate() + 500)/1000,
                        100*sf);
                }
                Process.exit(0);
            }

            if (Options.notes_position != null) {
                Options.disable_auto_grouping = true;
                GLib.printerr("--notes option detected. Disable auto grouping.\n");
            }

            // if pdfpc runs at a tablet we force the toolbox to be shown
            var seat = display.get_default_seat();
            var touchSeats = seat.get_slaves(Gdk.SeatCapabilities.TOUCH);
            if (touchSeats.length() > 0) {
                Options.toolbox_shown = true;
            }

            ConfigFileReader configFileReader = new ConfigFileReader();
            if (Options.no_install) {
                configFileReader.readConfig(Path.build_filename(Paths.SOURCE_PATH, "rc/pdfpcrc"));
            } else {
                configFileReader.readConfig(Path.build_filename(Paths.CONF_PATH, "pdfpcrc"));
            }
            var legacyUserConfig = Path.build_filename(Environment.get_home_dir(), ".pdfpcrc");
            var userConfig = Path.build_filename(GLib.Environment.get_user_config_dir(), "pdfpc", "pdfpcrc");
            if (GLib.FileUtils.test(userConfig, (GLib.FileTest.IS_REGULAR))) {
                // first, use the xdg config directory
                configFileReader.readConfig(userConfig);
            } else if (GLib.FileUtils.test(legacyUserConfig, (GLib.FileTest.IS_REGULAR))) {
                // if not found, use the legacy location
                configFileReader.readConfig(legacyUserConfig);
                GLib.printerr("Loaded pdfpcrc from legacy location. Please move your config file to %s\n", userConfig);
            }

#if MOVIES
            Gst.init(ref args);
#endif
            if (Options.list_actions) {
                GLib.print("Config file commands accepted by pdfpc:\n");
                string[] actions = PresentationController.getActionDescriptions();
                for (int i = 0; i < actions.length; i+=2) {
                    string tabAlignment = "\t";
                    if (actions[i].length < 12)
                        tabAlignment += "\t";
                    GLib.print("    %s%s=> %s\n", actions[i], tabAlignment, actions[i+1]);
                }

                return;
            }
            if (pdfFilename == null) {
                GLib.printerr("No pdf file given\n");
                Process.exit(1);
            } else if (!GLib.FileUtils.test(pdfFilename, (GLib.FileTest.IS_REGULAR))) {
                GLib.printerr("Pdf file \"%s\" not found\n", pdfFilename);
                Process.exit(1);
            }

            // parse size option
            // should be in the width:height format

            int width = -1, height = -1;
            if (Options.size != null) {
                int colonIndex = Options.size.index_of(":");

                width = int.parse(Options.size.substring(0, colonIndex));
                height = int.parse(Options.size.substring(colonIndex + 1));

                if (width < 1 || height < 1) {
                    GLib.printerr("Failed to parse --size=%s\n", Options.size);
                    Process.exit(1);

                }

                Options.windowed = true;
            }

            string cwd = GLib.Environment.get_current_dir();
            if (!GLib.Path.is_absolute(pdfFilename)) {
                pdfFilename = GLib.Path.build_filename(cwd, pdfFilename);
            }
            var pdfpc_location = Options.pdfpc_location;
            if (pdfpc_location != null && !GLib.Path.is_absolute(pdfpc_location)) {
                pdfpc_location = GLib.Path.build_filename(cwd, pdfpc_location);
            }

            if (pdfpc_location != null && !GLib.FileUtils.test(pdfpc_location, (GLib.FileTest.IS_REGULAR))) {
                GLib.printerr("Can't find custom pdfpc file at %s\n", pdfpc_location);
                Process.exit(1);
            }

            var metadata = new Metadata.Pdf(pdfFilename, pdfpc_location);

            // Initialize global controller and CacheStatus, to manage
            // crosscutting concerns between the different windows.
            this.controller = new PresentationController( metadata, Options.black_on_end );
            this.cache_status = new CacheStatus();

            set_styling();

            int primary_monitor_num = 0, secondary_monitor_num = 0;
            int presenter_monitor = -1, presentation_monitor = -1;
            int n_monitors = display.get_n_monitors();
            bool by_output = (Options.presentation_screen != null) || (Options.presenter_screen != null);
            for (int i = 0; i < n_monitors; i++) {
                // Not obvious what's right to do if n_monitors > 2...
                // But let's be realistic :)
                if ((by_output && Options.presenter_screen == display.get_monitor(i).get_model())
                    || display.get_monitor(i).is_primary()) {
                    primary_monitor_num = i;
                } else if (!by_output || Options.presentation_screen == display.get_monitor(i).get_model()) {
                    secondary_monitor_num = i;
                }
            }
            if (!Options.display_switch) {
                presenter_monitor    = primary_monitor_num;
                presentation_monitor = secondary_monitor_num;
            } else {
                presenter_monitor    = secondary_monitor_num;
                presentation_monitor = primary_monitor_num;
            }

            if (!Options.single_screen || !Options.display_switch) {
                this.controller.presenter = this.create_presenter(metadata,
                    presenter_monitor);
            }
            if (!Options.single_screen || Options.display_switch) {
                this.controller.presentation = this.create_presentation(metadata,
                    presentation_monitor, width, height);
            }

            // The windows are always displayed at last to be sure all caches
            // have been created at this point.
            if (this.controller.presentation != null) {
                this.controller.presentation.show_all();
                this.controller.presentation.update();
            }

            if (this.controller.presenter != null) {
                this.controller.presenter.show_all();
                this.controller.presenter.update();
            }

            if (Options.page >= 1 &&
                Options.page <= metadata.get_end_user_slide()) {
                int u = metadata.user_slide_to_real_slide(Options.page - 1,
                    false);
                this.controller.page_change_request(u, false);
            } else {
                GLib.printerr("Argument --page/-P must be between 1 and %d\n",
                    metadata.get_end_user_slide());
                Process.exit(1);
            }

            // Enter the Glib eventloop
            // Everything from this point on is completely signal based
            Gtk.main();
        }

        /**
         * Basic application entry point
         */
        public static int main (string[] args) {
            var application = new Application();
            application.run(args);

            return 0;
        }
    }
}
