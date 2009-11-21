/**
 * Presentation window
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
using Gdk;

/**
 * Window showing the currently active slide to be presented on a beamer
 */
public class PresentationWindow: Gtk.Window {
	
	/**
	 * Controller handling all the events which might happen. Furthermore it is
	 * responsible to update all the needed visual stuff if needed
	 */
	protected PresentationController presentation_controller = null;

    protected PdfImage pdf;

	/**
	 * Base constructor instantiating a new presentation window
	 */
	public PresentationWindow( string pdf_filename, int screen_num ) {
        this.destroy += (source) => {
            Gtk.main_quit();
        };

        Color black;
        Color.parse( "black", out black );
        this.modify_bg( StateType.NORMAL, black );

        var screen = Screen.get_default();

        Rectangle geometry;
        screen.get_monitor_geometry( screen_num, out geometry );

        var fixedLayout = new Fixed();
        this.add( fixedLayout );

        this.pdf = new PdfImage.from_pdf( 
            pdf_filename, 
            geometry.width, 
            geometry.height,
            !Application.disable_caching
        );
        // Center the scaled pdf on the monitor
        // In most cases it will however fill the full screen
        fixedLayout.put(
            this.pdf,
            (int)Math.floor( ( geometry.width - this.pdf.get_scaled_width() ) / 2.0 ),
            (int)Math.floor( ( geometry.height - this.pdf.get_scaled_height() ) / 2.0 )
        );

		this.key_press_event += this.on_key_pressed;

        this.move( geometry.x, geometry.y );
        this.fullscreen();

        this.reset();
	}

	/**
     * Set the presentation controller which is notified of keypresses and
     * other observed events
	 */
	public void set_presentation_controller( PresentationController controller ) {
		this.presentation_controller = controller;
	}

    /**
     * Switch the shown pdf to the next page
     */
    public void next_page() {
        this.pdf.next_page();
    }

    /**
     * Switch the shown pdf to the previous page
     */
    public void previous_page() {
        this.pdf.previous_page();
    }

	/**
	 * Handle keypress events on the window and, if neccessary send them to the
	 * presentation controller
	 */
	protected bool on_key_pressed( PresentationWindow source, EventKey key ) {
        if ( this.presentation_controller != null ) {
            this.presentation_controller.key_press( key );
        }
        return false;
	}

    /**
     * Reset to the initial presentation state
     */
    public void reset() {
        this.pdf.goto_page( 0 );
    }

    /**
     * Set the cache observer for the PdfImages on this window
     */
    public void set_cache_observer( CacheStatus observer ) {
        observer.monitor_pdf_image( this.pdf );
    }
}
