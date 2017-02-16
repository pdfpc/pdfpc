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
            { "disable-cache", 'c', 0, 0, ref Options.disable_caching, "Disable caching and pre-rendering of slides to save memory at the cost of speed.", null },
            { "time-of-day", 'C', 0, 0, ref Options.use_time_of_day, "Use the current time of the day for the timer", null},
            { "duration", 'd', 0, OptionArg.INT, ref Options.duration, "Duration in minutes of the presentation used for timer display.", "N" },
            { "end-time", 'e', 0, OptionArg.STRING, ref Options.end_time, "End time of the presentation. (Format: HH:MM (24h))", "T" },
            { "disable-auto-grouping", 'g', 0, 0, ref Options.disable_auto_grouping, "Disable auto detection and grouping of overlayed slides", null },
            { "last-minutes", 'l', 0, OptionArg.INT, ref Options.last_minutes, "Time in minutes, from which on the timer changes its color. (Default 5 minutes)", "N" },
            { "list-actions", 'L', 0, 0, ref Options.list_actions, "List actions supported in the config file(s)", null},
            { "notes", 'n', 0, OptionArg.STRING, ref Options.notes_position, "Position of notes on the pdf page (either left, right, top or bottom)", "P"},
            { "persist-cache", 'p', 0, 0, ref Options.persist_cache, "Persist the PNG cache on disk for faster startup.", null },
            { "page", 'P', 0, OptionArg.INT, ref Options.page, "Goto a specific page directly after startup", "PAGE" },
            { "switch-screens", 's', 0, 0, ref Options.display_switch, "Switch the presentation and the presenter screen.", null },
            { "single-screen", 'S', 0, 0, ref Options.single_screen, "Force to use only one screen", null },
            { "start-time", 't', 0, OptionArg.STRING, ref Options.start_time, "Start time of the presentation to be used as a countdown. (Format: HH:MM (24h))", "T" },
            { "version", 'v', 0, 0, ref Options.version, "Print the version string and copyright statement", null },
            { "windowed", 'w', 0, 0, ref Options.windowed, "Run in windowed mode (devel tool)", null},
            { "disable-compression", 'z', 0, 0, ref Options.disable_cache_compression, "Disable the compression of slide images to trade memory consumption for speed. (Avg. factor 30)", null },
            { "size", 'Z', 0, OptionArg.STRING, ref Options.size, "Size of the presentation window in width:height format (forces windowed mode)", null},
            { null }
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
            GLib.print("pdfpc v4.0.6\n"
                     + "(C) 2015-2017 Robert Schroll, Andreas Bilke, Andy Barry, Phillip Berndt and others\n"
                     + "(C) 2012 David Vilar\n"
                     + "(C) 2009-2011 Jakob Westhoff\n\n"
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

            var sourceCssPath = Path.build_filename(Paths.SOURCE_PATH, "rc/pdfpc.css");
            var distCssPath = Path.build_filename(Paths.ICON_PATH, "pdfpc.css");
            var legacyUserCssPath = Path.build_filename(GLib.Environment.get_user_config_dir(), "pdfpc.css");
            var userCssPath = Path.build_filename(GLib.Environment.get_user_config_dir(), "pdfpc", "pdfpc.css");

            try {
                // pdfpc.css in dist path or in build directory is mandatory
                if (GLib.FileUtils.test(sourceCssPath, (GLib.FileTest.IS_REGULAR))) {
                    globalProvider.load_from_path(sourceCssPath);
                } else if (GLib.FileUtils.test(distCssPath, (GLib.FileTest.IS_REGULAR))) {
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
            Gtk.init(ref args);

            string pdfFilename = this.parse_command_line_options(ref args);

            if (Options.version) {
                print_version();
                Process.exit(0);
            }

            if (Options.notes_position != null) {
                Options.disable_auto_grouping = true;
                GLib.printerr("--notes option detected. Disable auto grouping.\n");
            }

            ConfigFileReader configFileReader = new ConfigFileReader();
            configFileReader.readConfig(Path.build_filename(Paths.SOURCE_PATH, "rc/pdfpcrc"));
            configFileReader.readConfig(Path.build_filename(Paths.CONF_PATH, "pdfpcrc"));
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
                    if (actions[i].length < 8)
                        tabAlignment += "\t";
                    GLib.print("\t%s%s=> %s\n", actions[i], tabAlignment, actions[i+1]);
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

            GLib.Environment.set_current_dir(GLib.Path.get_dirname(pdfFilename));

            var metadata = new Metadata.Pdf(GLib.Path.get_basename(pdfFilename));

            // Initialize global controller and CacheStatus, to manage
            // crosscutting concerns between the different windows.
            this.controller = new PresentationController( metadata, Options.black_on_end );
            this.cache_status = new CacheStatus();

            set_styling();

            var screen = Gdk.Screen.get_default();
            if (!Options.windowed && !Options.single_screen && screen.get_n_monitors() > 1) {
                int presenter_monitor, presentation_monitor;
                if (Options.display_switch != true) {
                    presenter_monitor = screen.get_primary_monitor();
                } else {
                    presenter_monitor = (screen.get_primary_monitor() + 1) % 2;
                }

                presentation_monitor = (presenter_monitor + 1) % 2;
                this.controller.presenter = this.create_presenter(metadata, presenter_monitor);
                this.controller.presentation = this.create_presentation(metadata, presentation_monitor, width, height);
            } else if (Options.windowed && !Options.single_screen) {
                this.controller.presenter = this.create_presenter(metadata, -1);
                this.controller.presentation = this.create_presentation(metadata, -1, width, height);
            } else {
                if (!Options.display_switch) {
                    this.controller.presenter = this.create_presenter(metadata, -1);
                } else {
                    this.controller.presentation = this.create_presentation(metadata, -1, width, height);
                }
            }

            // The windows are always displayed at last to be sure all caches have
            // been created at this point.
            if (this.controller.presentation != null) {
                this.controller.presentation.show_all();
                this.controller.presentation.update();
            }

            if (this.controller.presenter != null) {
                this.controller.presenter.show_all();
                this.controller.presenter.update();
            }

            if (Options.page >= 1 && Options.page <= metadata.get_end_user_slide()) {
                int u = metadata.user_slide_to_real_slide(Options.page - 1, false);
                this.controller.page_change_request(u, false);
            } else {
                GLib.printerr("Argument --page/-P must be between %d and %d\n", 1, metadata.get_end_user_slide());
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
