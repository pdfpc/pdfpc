/**
 * Main application file
 *
 * This file is part of pdf-presenter-console.
 *
 * pdf-presenter-console is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3 of the License.
 *
 * pdf-presenter-console is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * pdf-presenter-console; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

using Gtk;

namespace org.westhoffswelt.pdfpresenter {
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
            { "duration", 'd', 0, OptionArg.INT, ref Options.duration, "Duration in minutes of the presentation used for timer display. (Default 45 minutes)", "N" },
            { "last-minutes", 'l', 0, OptionArg.INT, ref Options.last_minutes, "Time in minutes, from which on the timer changes its color. (Default 5 minutes)", "N" },
            { "current-size", 'u', 0, OptionArg.INT, ref Options.current_size, "Percentage of the presenter screen to be used for the current slide. (Default 60)", "N" },
            { "switch-screens", 's', 0, 0, ref Options.display_switch, "Switch the presentation and the presenter screen.", null },
            { "disable-cache", 'c', 0, 0, ref Options.disable_caching, "Disable caching and pre-rendering of slides to save memory at the cost of speed.", null },
            { "enable-compression", 'z', 0, 0, ref Options.enable_cache_compression, "Enable the compression of slide images to trade speed for memory consumption on low memory systems. (Avg. factor 1/30)", null },
            { null }
        };

        /**
         * Parse the commandline and apply all found options to there according
         * static class members.
         *
         * On error the usage help is shown and the application terminated with an
         * errorcode 1
         */
        protected void parse_command_line_options( string[] args ) {
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

            if ( args.length != 2 ) {
                stderr.printf( "%s", context.get_help( true, null ) );
                Posix.exit( 1 );
            }
        }

        /**
         * Create and return a PresenterWindow using the specified monitor
         * while displaying the given file
         */
        private Window.Presenter create_presenter_window( string filename, int monitor ) {
            var presenter_window = new Window.Presenter( filename, monitor );
            controller.register_controllable( presenter_window );
            presenter_window.set_cache_observer( this.cache_status );

            return presenter_window;
        }

        /**
         * Create and return a PresentationWindow using the specified monitor
         * while displaying the given file
         */
        private Window.Presentation create_presentation_window( string filename, int monitor ) {
            var presentation_window = new Window.Presentation( filename, monitor );
            controller.register_controllable( presentation_window );
            presentation_window.set_cache_observer( this.cache_status );

            return presentation_window;
        }

        /**
         * Main application function, which instantiates the windows and
         * initializes the Gtk system.
         */
        public void run( string[] args ) {
            stdout.printf( "Pdf-Presenter-Console Version 2.x DEVELOPMENT Copyright 2009-2010 Jakob Westhoff\n" );

            Gdk.threads_init();
            Gtk.init( ref args );

            // Initialize the application wide mutex objects
            MutexLocks.init();

            this.parse_command_line_options( args );

            stdout.printf( "Initializing rendering...\n" );
           
            // Initialize global controller and CacheStatus, to manage
            // crosscutting concerns between the different windows.
            this.controller = new PresentationController();
            this.cache_status = new CacheStatus();

            int presenter_monitor, presentation_monitor;
            if ( Options.display_switch != true ) {
                presenter_monitor    = 0;
                presentation_monitor = 1;
            }
            else {
                presenter_monitor    = 1;
                presentation_monitor = 0;
            }

            if ( Gdk.Screen.get_default().get_n_monitors() > 1 ) {
                this.presentation_window = 
                    this.create_presentation_window( args[1], presentation_monitor );
                this.presenter_window = 
                    this.create_presenter_window( args[1], presenter_monitor );
            }
            else {
                stdout.printf( "Only one screen detected falling back to simple presentation mode.\n" );
                // Decide which window to display by indirectly examining the
                // display_switch flag This allows for training sessions with
                // one monitor displaying the presenter screen
                if ( presenter_monitor == 1 ) {
                    this.presentation_window = 
                        this.create_presentation_window( args[1], 0 );
                }
                else {
                    this.presenter_window = 
                        this.create_presenter_window( args[1], 0 );
                }
            }

            // The windows are always displayed at last to be sure all caches have
            // been created at this point.
            if ( this.presentation_window != null ) {
                this.presentation_window.show_all();
            }
            
            if ( this.presenter_window != null ) {
                this.presenter_window.show_all();
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
