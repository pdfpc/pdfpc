/**
 * Main application file
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

using Gtk;

namespace pdfpc {
    /**
     * Pdf Presenter Console main application class
     *
     * This class contains the main method as well as all the logic needed for
     * initializing the application, like commandline parsing and window creation.
     */
    public class Application: GLib.Object {
        /**
         * Window which shows the current slide in fullscreen
         *
         * This window is supposed to be shown on the beamer
         */
        private Window.Presentation presentation_window;

        /**
         * Presenter window showing the current and the next slide as well as
         * different other meta information useful for the person giving the
         * presentation.
         */
        private Window.Presenter presenter_window;

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
            { "duration", 'd', 0, OptionArg.INT, ref Options.duration, "Duration in minutes of the presentation used for timer display.", "N" },
            { "end-time", 'e', 0, OptionArg.STRING, ref Options.end_time, "End time of the presentation. (Format: HH:MM (24h))", "T" },
            { "last-minutes", 'l', 0, OptionArg.INT, ref Options.last_minutes, "Time in minutes, from which on the timer changes its color. (Default 5 minutes)", "N" },
            { "start-time", 't', 0, OptionArg.STRING, ref Options.start_time, "Start time of the presentation to be used as a countdown. (Format: HH:MM (24h))", "T" },
            { "current-size", 'u', 0, OptionArg.INT, ref Options.current_size, "Percentage of the presenter screen to be used for the current slide. (Default 60)", "N" },
            { "overview-min-size", 'o', 0, OptionArg.INT, ref Options.min_overview_width, "Minimum width for the overview miniatures, in pixels. (Default 150)", "N" },
            { "switch-screens", 's', 0, 0, ref Options.display_switch, "Switch the presentation and the presenter screen.", null },
            { "disable-cache", 'c', 0, 0, ref Options.disable_caching, "Disable caching and pre-rendering of slides to save memory at the cost of speed.", null },
            { "disable-compression", 'z', 0, 0, ref Options.disable_cache_compression, "Disable the compression of slide images to trade memory consumption for speed. (Avg. factor 30)", null },
            { "black-on-end", 'b', 0, 0, ref Options.black_on_end, "Add an additional black slide at the end of the presentation", null },
            { "single-screen", 'S', 0, 0, ref Options.single_screen, "Force to use only one screen", null },
            { "list-actions", 'L', 0, 0, ref Options.list_actions, "List actions supported in the config file(s)", null},
            { "windowed", 'w', 0, 0, ref Options.windowed, "Run in windowed mode (devel tool)", null},
            { null }
        };

        /**
         * Parse the commandline and apply all found options to there according
         * static class members.
         *
		 * Returns the name of the pdf file to open (or null if not present)
         */
        protected string? parse_command_line_options( string[] args ) {
            var context = new OptionContext( "<pdf-file>" );

            context.add_main_entries( options, null );
            
            try {
                context.parse( ref args );
            }
            catch( OptionError e ) {
                stderr.printf( "\n%s\n\n", e.message );
                stderr.printf( "%s", context.get_help( true, null ) );
                Posix.exit( 1 );
            }
            if ( args.length < 2 ) {
				return null;
            } else {
				return args[1];
			}
        }

        /**
         * Create and return a PresenterWindow using the specified monitor
         * while displaying the given file
         */
        private Window.Presenter create_presenter_window( Metadata.Pdf metadata, int monitor ) {
            var presenter_window = new Window.Presenter( metadata, monitor, this.controller );
            //controller.register_controllable( presenter_window );
            presenter_window.set_cache_observer( this.cache_status );

            return presenter_window;
        }

        /**
         * Create and return a PresentationWindow using the specified monitor
         * while displaying the given file
         */
        private Window.Presentation create_presentation_window( Metadata.Pdf metadata, int monitor ) {
            var presentation_window = new Window.Presentation( metadata, monitor, this.controller );
            //controller.register_controllable( presentation_window );
            presentation_window.set_cache_observer( this.cache_status );

            return presentation_window;
        }

        /**
         * Main application function, which instantiates the windows and
         * initializes the Gtk system.
         */
        public void run( string[] args ) {
            stdout.printf( "pdfpc v3.1.1\n"
                           + "(C) 2012 David Vilar\n"
                           + "(C) 2009-2011 Jakob Westhoff\n\n" );

            Gdk.threads_init();
            Gtk.init( ref args );

            string pdfFilename = this.parse_command_line_options( args );
            if (Options.list_actions) {
				stdout.printf("Config file commands accepted by pdfpc:\n");
				string[] actions = PresentationController.getActionDescriptions();
				for (int i = 0; i < actions.length; i+=2) {
					string tabAlignment = "\t";
					if (actions[i].length < 8)
						tabAlignment += "\t";
					stdout.printf("\t%s%s=> %s\n", actions[i], tabAlignment, actions[i+1]);
				}
                return;
            }
			if (pdfFilename == null) {
				stderr.printf( "Error: No pdf file given\n");
				Posix.exit(1);
			}

            // Initialize the application wide mutex objects
            MutexLocks.init();

            stdout.printf( "Initializing rendering...\n" );

            var metadata = new Metadata.Pdf( pdfFilename );
            if ( Options.duration != 987654321u )
                metadata.set_duration(Options.duration);

            // Initialize global controller and CacheStatus, to manage
            // crosscutting concerns between the different windows.
            this.controller = new PresentationController( metadata, Options.black_on_end );
            this.cache_status = new CacheStatus();

            ConfigFileReader configFileReader = new ConfigFileReader(this.controller);
            configFileReader.readConfig(etc_path + "/pdfpcrc");
            configFileReader.readConfig(Environment.get_home_dir() + "/.pdfpcrc");

            var screen = Gdk.Screen.get_default();
            if ( !Options.windowed && !Options.single_screen && screen.get_n_monitors() > 1 ) {
                int presenter_monitor, presentation_monitor;
                if ( Options.display_switch != true )
                    presenter_monitor    = screen.get_primary_monitor();
                else
                    presenter_monitor    = (screen.get_primary_monitor() + 1) % 2;
                presentation_monitor = (presenter_monitor + 1) % 2;
                this.presentation_window = 
                    this.create_presentation_window( metadata, presentation_monitor );
                this.presenter_window = 
                    this.create_presenter_window( metadata, presenter_monitor );
            } else if (Options.windowed && !Options.single_screen) {
                this.presenter_window =
                    this.create_presenter_window( metadata, -1 );
                this.presentation_window =
                    this.create_presentation_window( metadata, -1 );
            } else {
                    if ( !Options.display_switch)
                        this.presenter_window =
                            this.create_presenter_window( metadata, -1 );
                    else
                        this.presentation_window =
                            this.create_presentation_window( metadata, -1 );
            }

            // The windows are always displayed at last to be sure all caches have
            // been created at this point.
            if ( this.presentation_window != null ) {
                this.presentation_window.show_all();
                this.presentation_window.update();
            }
            
            if ( this.presenter_window != null ) {
                this.presenter_window.show_all();
                this.presenter_window.update();
            }

            // Enter the Glib eventloop
            // Everything from this point on is completely signal based
            Gdk.threads_enter();
            Gtk.main();
            Gdk.threads_leave();
        }

        /**
         * Basic application entry point
         */
        public static int main ( string[] args ) {
            var application = new Application();
            application.run( args );

            return 0;
        }
    }
}
