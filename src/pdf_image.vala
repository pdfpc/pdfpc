/**
 * Pdf Image widget
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
using Poppler;

namespace org.westhoffswelt.pdfpresenter {

/**
 * Generic GTK image widget which is capable of displaying a pdf file using the
 * Poppler library.
 */
public class PdfImage: Gtk.Image 
{
	/**
	 * Filename of the pdf file to be displayed
	 */
	protected GLib.File pdf_file;
	
	/**
	 * Poppler document representing the loaded pdf file
	 */
	protected Document document;
    
    /**
     * Number of pages in the document
     */
    protected int page_count;

	/**
	 * Currently displayed page
	 */
	protected int page = 0;

    /**
     * Factor the pdf needs to be scaled with to fillup the widget
     */
    protected double scale_factor = 0;

    /**
     * Pre calculated scaled height of the pdf allowing it to fit the window
     * and still have the correct aspect ratio.
     */
    protected int scaled_height = 0;

    /**
     * Pre calculated scaled width of the pdf allowing it to fit the window
     * and still have the correct aspect ratio.
     */
    protected int scaled_width = 0;

    /**
     * Cache storage for rendered pdf pages
     */
    protected Pixmap[] rendered_pages;

	/**
	 * Mutex to lock rendered_pages during thread access
	 */
	protected GLib.Mutex rendered_pages_mutex = new GLib.Mutex();

    /**
     * Should rendered images be cached?
     */
    protected bool cached;

    /**
     * CacheStatus widget which is informed about the creation of cached
     * elements
     */
    protected CacheStatus cache_observer = null;

    /**
     * Create a new pdf image from a given pdf filename
     */
	public PdfImage.from_pdf( string filename, int width, int height, bool cached ) 
	{
		this.pdf_file = File.new_for_path( filename );

		try 
		{
			this.document = new Poppler.Document.from_file(
				this.pdf_file.get_uri(),
				""
			);
		}
		catch( GLib.Error e ) 
		{
			error( "Unable to load pdf file: %s", e.message );
		}

        this.page_count = this.document.get_n_pages();
	
        this.rendered_pages = new Pixmap[this.page_count];

        this.calculate_scaleing( width, height );

        this.cached = cached;

		this.add_events( EventMask.STRUCTURE_MASK );
		Signal.connect_after( this, "realize", (GLib.Callback)this.on_realize, this );
	}

	protected void on_realize( PdfImage source ) {
		unowned Thread render_thread = null;
        if ( this.cached == true ) {
			// Start the rendering thread
			render_thread = Thread.create( 
				this.render_all_pages_thread,
				true
			);
		}
		
        this.blitToScreen( this.get_rendered_page( 0 ) );
	}

	/**
	 * Render a specific page of the pdf loaded pdf document
	 */
	public void goto_page( int page ) 
    throws PdfImageError
	{
         if ( page >= this.page_count || page < 0 ) {
             throw new PdfImageError.PAGE_DOES_NOT_EXIST( "The requested page does not exist in the document." );
         }
         this.page = page;
         this.blitToScreen( this.get_rendered_page( page ) );
	}

	/**
	 * Jump to the next page.
     * 
	 * If the last page is reached no change will be done.
	 */
	public void next_page() 
	{
        try {
            this.goto_page( this.page + 1 );
        }
        catch( PdfImageError e ) {
            // Do nothing
        }
	}

    /**
     * Switch to the previous page if there is no previous page the nothing
     * will be done.
     */
    public void previous_page() {
        try {
            this.goto_page( this.page - 1 );
        }
        catch( PdfImageError e ) {
            // Do nothing
        }
    }

    /**
	 * Return the number of the page, which is currently displayed
	 */
	public int get_page() 
	{
		return this.page;
	}

    /**
     * Return the page count of the currently loaded document
     */
    public int get_page_count() {
        return this.page_count;
    }

    /**
     * Get the width of the widget after scaleing calculation is done
     */
    public int get_scaled_width() {
        return this.scaled_width;
    }

    /**
     * Get the height of the widget after scaleing calculation is done
     */
    public int get_scaled_height() {
        return this.scaled_height;
    }

    /**
     * Calculate the scaling and position of the pdf to fill the provided
     * space.
     */
    protected void calculate_scaleing( int width, int height ) {
		var page = this.document.get_page( this.page );

		double page_width, page_height;
		page.get_size( out page_width, out page_height );

		double scale_width = width / page_width;
		double scale_height = height / page_height;

        this.scale_factor = ( scale_width > scale_height ) ? scale_height : scale_width;

        this.scaled_width = (int)Math.ceil( page_width * this.scale_factor );
        this.scaled_height = (int)Math.ceil( page_height * this.scale_factor );
    }

    /**
     * Render the given pdf document page and return its pixbuf
     */
    protected Pixmap render_page( int page_number ) {
        var background_pixmap = new Pixmap( null, this.scaled_width, this.scaled_height, 24 );
        var gc = new GC( background_pixmap );
        Color white;
        Color.parse( "white", out white );
        gc.set_rgb_fg_color( white );
        background_pixmap.draw_rectangle( gc, true, 0, 0, this.scaled_width, this.scaled_height );

        var pdf_pixbuf = new Pixbuf( 
            Colorspace.RGB, 
            false, 
            8, 
            this.scaled_width,
            this.scaled_height
        );
		
		Application.poppler_mutex.lock();
		var page = this.document.get_page( page_number );
		page.render_to_pixbuf( 
			0,
			0,
			this.scaled_width,
			this.scaled_height,
			this.scale_factor,
			0,
			pdf_pixbuf
		);
		Application.poppler_mutex.unlock();
	
        background_pixmap.draw_pixbuf( 
            gc,
            pdf_pixbuf,
            0, /* srcx */
            0, /* srcy */
            0, /* dstx */
            0, /* dsty */
            this.scaled_width,
            this.scaled_height,
            RgbDither.NONE,
            0,
            0
        );

        return background_pixmap;
    }

	/**
	 * Render all pdf pages to memory pixmaps
	 * 
	 * This is done in a seperate thread to allow the presentation to run in
	 * this time
	 */
	protected void* render_all_pages_thread() 
	{
        // After the initial call sleep for 2.5 seconds to allow the normal
        // redering windows to handle their initialization fast and efficient.
        Thread.self().usleep( 2500000 );

		var page_count = this.page_count;
        for( var i=0; i<page_count; ++i ) {
			Gdk.threads_enter();
			this.rendered_pages_mutex.lock();
			if ( this.rendered_pages[i] == null ) {
				this.rendered_pages[i] = this.render_page( i );
			}
			this.rendered_pages_mutex.unlock();
            if ( this.cache_observer != null ) {
                this.cache_observer.new_cache_entry_created();
            }
			Gdk.threads_leave();
			Thread.self().yield();
        }

		return null;
	}

    /**
     * Display a given pixmap on screen
     */
    protected void blitToScreen( Pixmap pixmap ) {
        this.set_from_pixmap( pixmap, null );
    }

    /**
     * Return a rendered page as a pixmap
     *
     * This function takes care of correctly caching the rendered page and
     * should therefore be used instead of calling render_page directly.
     */
    protected Pixmap get_rendered_page( int page ) {
        if ( this.cached != true ) {
            // Caching is fully disabled
            return this.render_page( page );
        }

		this.rendered_pages_mutex.lock();
		if ( this.rendered_pages[page] == null ) {
			this.rendered_pages[page] = this.render_page( page );
		}
		this.rendered_pages_mutex.unlock();
		return this.rendered_pages[page];
    }

    /**
     * Set the cache observer element which is informed about new cached items
     */
    public void set_cache_observer( CacheStatus observer ) {
        this.cache_observer = observer;
    }

}

errordomain PdfImageError {
    PAGE_DOES_NOT_EXIST;
}

}
