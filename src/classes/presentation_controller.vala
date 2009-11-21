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

    protected PresentationWindow presentation_window = null;

    protected PresenterWindow presenter_window = null;

    public void key_press( Gdk.EventKey key ) {
        switch( key.keyval ) {
            case 0xff53: /* Cursor right */
            case 0xff56: /* Page down */
                if ( this.presentation_window != null ) {
                    this.presentation_window.next_page();
                }

                if ( this.presenter_window != null ) {
                    this.presenter_window.next_page();
                }
            break;
            case 0xff51: /* Cursor left */
            case 0xff55: /* Page Up */
                if ( this.presentation_window != null ) {
                    this.presentation_window.previous_page();
                }

                if ( this.presenter_window != null ) {
                    this.presenter_window.previous_page();
                }
            break;
            case 0xff1b: /* Escape */
                Gtk.main_quit();
            break;
            case 0xff50: /* Home */
                if ( this.presentation_window != null ) {
                    this.presentation_window.reset();
                }

                if ( this.presenter_window != null ) {
                    this.presenter_window.reset();
                }
            break;
        }
    }

    public void set_presentation_window( PresentationWindow window ) {
        this.presentation_window = window;
    }

    public void set_presenter_window( PresenterWindow window ) {
        this.presenter_window = window;
    }
}

}
