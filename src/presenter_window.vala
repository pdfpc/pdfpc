/**
 * Presentater window
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
 * Window showing the currently active and next slide.
 *
 * Other useful information like time slide count, ... can be displayed here as
 * well.
 */
public class PresenterWindow: Gtk.Window {
	
	/**
	 * Controller handling all the events which might happen. Furthermore it is
	 * responsible to update all the needed visual stuff if needed
	 */
	protected PresentationController presentation_controller = null;

    /**
     * Image of the currently shown slide
     */
    protected PdfImage current_slide;

    /**
     * Image of the next slide to be shown
    */
    protected PdfImage next_slide;

    /**
     * Countdown until the presentation ends
     */
    protected Label countdown;

    /**
     * Slide progress label ( eg. "23/42" )
     */
    protected Label slide_progress;

    /**
     * Timer used to measure the duration
     */
    protected uint timer = 0;

    /**
     * The left duration of the presentation
     */
    protected uint presentation_time;

	/**
	 * Base constructor instantiating a new presenter window
	 */
	public PresenterWindow( string pdf_filename, int screen_num ) {
        this.destroy += (source) => {
            Gtk.main_quit();
        };

        this.presentation_time = Application.duration * 60;

        Color black;
        Color.parse( "black", out black );
        this.modify_bg( StateType.NORMAL, black );

        var screen = Screen.get_default();

        Rectangle geometry;
        screen.get_monitor_geometry( screen_num, out geometry );

        var fixedLayout = new Fixed();
        this.add( fixedLayout );

        // We need the value of 90% height a lot of times. Therefore store it
        // in advance
        var bottom_position = (int)Math.floor( geometry.height * 0.9 );
        var bottom_height = geometry.height - bottom_position;

        // The currentslide needs to be bigger than the next one it, It takes
        // two third of of the available screen width while max taking 90 percent of the height
        this.current_slide = new PdfImage.from_pdf( 
            pdf_filename,
            (int)Math.floor( geometry.width * 0.6 ),
            bottom_position,
            !Application.disable_caching,
            !Application.disable_pre_render
        );
        // Position it in the top left corner
        fixedLayout.put( this.current_slide, 0, 0 );

        //The next slide is next to the current one and takes up the remaining
        //width
        var next_slideWidth = geometry.width - this.current_slide.get_scaled_width();
        this.next_slide = new PdfImage.from_pdf( 
            pdf_filename,
            next_slideWidth,
            bottom_position,
            !Application.disable_caching,
            !Application.disable_pre_render
        );
        // Position it at the top besides the current slide
        fixedLayout.put( this.next_slide, this.current_slide.get_scaled_width(), 0 );

        // Color needed for the labels
        Color white;
        Color.parse( "white", out white );

        // Initial font needed for the labels
        // We approximate the point size using pt = px * .75
        var font = Pango.FontDescription.from_string( "Verdana" );
        font.set_size( 
            (int)Math.floor( bottom_height * 0.8 * 0.75 ) * Pango.SCALE
        );

        // The countdown timer is centered in the 90% bottom part of the screen
        // It takes 3/4 of the available width
        this.countdown = new Label( "00:00" );
        this.countdown.set_justify( Justification.CENTER );
        this.countdown.modify_fg( StateType.NORMAL, white );
        this.countdown.modify_font( font );
        this.countdown.set_size_request( 
            (int)Math.floor( geometry.width * 0.75 ),
            bottom_height - 10
        );
        fixedLayout.put( this.countdown, 0, bottom_position - 10 );


        // The slide counter is centered in the 90% bottom part of the screen
        // It takes 1/4 of the available width on the right
        this.slide_progress = new Label( "23/42" );
        this.slide_progress.set_justify( Justification.CENTER );
        this.slide_progress.modify_fg( StateType.NORMAL, white );
        this.slide_progress.modify_font( font );
        this.slide_progress.set_size_request( 
            (int)Math.floor( geometry.width * 0.25 ),
            bottom_height - 10 
        );
        fixedLayout.put(
            this.slide_progress,
            (int)Math.ceil( geometry.width * 0.75 ),
            bottom_position - 10
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
        this.current_slide.next_page();
        this.next_slide.next_page();
        this.update_slide_count();

        // Initialize timer on first slide change
        if ( this.timer == 0 ) {
            this.timer = Timeout.add( 1000, this.on_timeout );
        }
    }

    /**
     * Switch to the previous page
     */
    public void previous_page() {
		if ( (int)Math.fabs( (double)( this.current_slide.get_page() - this.next_slide.get_page() ) ) >= 1
		  && this.current_slide.get_page() != 0 ) {
			// Only move the next slide back if there is a difference of at
			// least one slide between current and next
			this.next_slide.previous_page();
		}
        this.current_slide.previous_page();
        this.update_slide_count();
    }

    /**
     * Reset the presentation display to the initial status
     */
    public void reset() {
        this.current_slide.goto_page( 0 );
        this.next_slide.goto_page( 1 );

        if ( this.timer != 0 ) {
            Source.remove( this.timer );
            this.timer = 0;
        }

        this.presentation_time = Application.duration * 60;

        this.update_duration();
        this.update_slide_count();
    }

	/**
	 * Handle keypress events on the window and, if neccessary send them to the
	 * presentation controller
	 */
	protected bool on_key_pressed( PresenterWindow source, EventKey key ) {
        if ( this.presentation_controller != null ) {
            this.presentation_controller.key_press( key );
        }
        return false;
	}

    /**
     * Handle the timeout which is registered for every second to show the left
     * duration time of the presentation.
     */
    protected bool on_timeout() {
        --this.presentation_time;

        this.update_duration();

        if ( this.presentation_time <= 0 ) {
            return false;
        }
        return true;
    }

    /**
     * Update the duration timer
     */
    protected void update_duration() {
        uint hours, minutes, seconds;

        hours = this.presentation_time / 60 / 60;
        minutes = this.presentation_time / 60 % 60;
        seconds = this.presentation_time % 60 % 60;
        
        this.countdown.set_text( 
            "%.2u:%.2u:%.2u".printf( 
                hours,
                minutes,
                seconds
            )
        );
    }

    /**
     * Update the slide count view
     */
    protected void update_slide_count() {
        this.slide_progress.set_text( 
            "%d/%d".printf( 
                this.current_slide.get_page() + 1, 
                this.current_slide.get_page_count()
            )        
        );
    }
}
