/**
 * Presentation Event controller
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

using GLib;

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Controller handling all the triggered events/signals
     */
    public class PresentationController: Object {

        /**
         * Controllables which are registered with this presentation controller.
         */
        protected List<Controllable> controllables;

        /**
         * Instantiate a new controller
         */
        public PresentationController() {
            this.controllables = new List<Controllable>();
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
        public void key_press( Gdk.EventKey key ) {
            switch( key.keyval ) {
                case 0xff0d: /* Return */
                case 0xff53: /* Cursor right */
                case 0xff56: /* Page down */
                case 0x020:  /* Space */
                    this.controllables_next_page();
                break;
                case 0xff51: /* Cursor left */
                case 0xff55: /* Page Up */
                    this.controllables_previous_page();
                break;
                case 0xff1b: /* Escape */
                case 0x071:  /* q */
                    Gtk.main_quit();
                break;
                case 0xff50: /* Home */
                    this.controllables_reset();
                break;
            }
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

            controllable.set_controller( this );
            this.controllables.append( controllable );
            
            return true;
        }
        
        /**
         * Move all registered controllables to the next page
         */
        protected void controllables_next_page() {
            foreach( Controllable c in this.controllables ) {
                c.next_page();
            }
        }

        /**
         * Move all registered controllables to the previous page
         */
        protected void controllables_previous_page() {
            foreach( Controllable c in this.controllables ) {
                c.previous_page();
            }
        }

        /**
         * Reset all registered controllables to their initial state
         */
        protected void controllables_reset() {
            foreach( Controllable c in this.controllables ) {
                c.reset();
            }
        }
    }
}
