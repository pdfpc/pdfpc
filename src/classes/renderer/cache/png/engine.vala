/**
 * PNG cache store
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
 * Copyright 2015 Andreas Bilke
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

namespace pdfpc.Renderer.Cache {
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
         * Initialize the cache store
         */
        public Engine( Metadata.Pdf metadata ) {
            base( metadata );
            this.storage = new PNG.Item[this.metadata.get_slide_count()];
        }

        /**
         * Store a surface in the cache using the given index as identifier
         */
        public override void store( uint index, Cairo.ImageSurface surface ) {
            png_store(index, surface);
        }

        protected void png_store(uint index, Cairo.ImageSurface surface ) {
            Gdk.Pixbuf pixbuf = Gdk.pixbuf_get_from_surface(surface, 0, 0, surface.get_width(),
                surface.get_height());
            uint8[] buffer;

            try {
                pixbuf.save_to_buffer( out buffer, "png", "compression", "1", null );
            }
            catch( Error e ) {
                GLib.printerr("Could not generate PNG cache image for slide %u: %s\n", index, e.message);
                Process.exit(1);
            }

            var item = new PNG.Item( buffer );
            this.storage[index] = item;
        }

        /**
         * Retrieve a stored surface from the cache.
         *
         * If no item with the given index is available null is returned
         */
        public override Cairo.ImageSurface? retrieve( uint index ) {
            return png_retrieve(index);
        }

        protected Cairo.ImageSurface? png_retrieve( uint index ) {
            var item = this.storage[index];
            if ( item == null ) {
                return null;
            }

            var loader = new Gdk.PixbufLoader();
            try {
                loader.write( item.get_png_data() );
                loader.close();
            }
            catch( Error e ) {
                GLib.printerr("Could not load cached PNG image for slide %u: %s\n", index, e.message);
                Process.exit(1);
            }

            var pixbuf = loader.get_pixbuf();
            Cairo.ImageSurface surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,
                pixbuf.get_width(), pixbuf.get_height());
            Cairo.Context cr = new Cairo.Context(surface);
            Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0);
            cr.rectangle(0, 0, pixbuf.get_width(), pixbuf.get_height());
            cr.fill();

            return surface;
        }
    }
}

