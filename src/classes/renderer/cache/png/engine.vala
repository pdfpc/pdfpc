/**
 * PNG cache store
 *
 * This file is part of pdf-presenter-console.
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

using GLib;
using Gdk;
using Cairo;

using org.westhoffswelt.pdfpresenter;

namespace org.westhoffswelt.pdfpresenter.Renderer.Cache {
    /**
     * Cache store which holds all given items in memory as compressed png
     * images
     */
    public class PNG.Engine: Renderer.Cache.Base {
        /**
         * In memory storage for all the given pixmaps
         */
        protected PNG.Item[] storage = null;

        /**
         * Mutex used to limit access to storage array to one thread at a time.
         *
         * Unfortunately the vala lock statement does not work here.
         */
        protected Mutex mutex = new Mutex();

        /**
         * Initialize the cache store
         */
        public Engine( Metadata.Base metadata ) {
            base( metadata );

            this.mutex.lock();
            this.storage = new PNG.Item[this.metadata.get_slide_count()];
            this.mutex.unlock();
        }

        /**
         * Store a pixmap in the cache using the given index as identifier
         */
        public override void store( uint index, Pixmap pixmap ) {
            int pixmap_width, pixmap_height;
            pixmap.get_size( out pixmap_width, out pixmap_height );

            // The pixbuf has to be created before being handed over to the
            // pixbuf_get_from_drawable, because Vala hightens the refcount of
            // the return value of this function. If a new pixbuf is created by
            // the function directly it will have a refcount of 2 afterwards
            // and thereby will not be freed.
            var pixbuf = new Pixbuf( 
                Colorspace.RGB,
                false,
                8,
                pixmap_width,
                pixmap_height
            );
            pixbuf_get_from_drawable( 
                pixbuf,
                pixmap,
                null,
                0, 0,
                0, 0,
                pixmap_width, pixmap_height
            );

            uint8[] buffer;

            try {
                pixbuf.save_to_buffer( out buffer, "png", "compression", "1", null );           
            }
            catch( Error e ) {
                error( "Could not generate PNG cache image for slide %u: %s", index, e.message );
            }

            var item = new PNG.Item( buffer );
            
            this.mutex.lock();
            this.storage[index] = item;
            this.mutex.unlock();
        }

        /**
         * Retrieve a stored pixmap from the cache.
         *
         * If no item with the given index is available null is returned
         */
        public override Pixmap? retrieve( uint index ) {
            var item = this.storage[index];
            if ( item == null ) {
                return null;
            }

            var loader = new PixbufLoader();
            try {
                loader.write( item.get_png_data() );
                loader.close();
            }
            catch( Error e ) {
                error( "Could not load cached PNG image for slide %u: %s", index, e.message );
            }

            var pixbuf = loader.get_pixbuf();

            var pixmap = new Gdk.Pixmap( 
                null, 
                pixbuf.get_width(),
                pixbuf.get_height(),
                24
            );

            Context cr = Gdk.cairo_create( pixmap );
            Gdk.cairo_set_source_pixbuf( cr, pixbuf, 0, 0 );
            cr.rectangle(
                0,
                0,
                pixbuf.get_width(),
                pixbuf.get_height()
            );
            cr.fill();

            return pixmap;
        }
    }
}
