/**
 * Cache store
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
 * Copyright 2015 Andreas Bilke
 * Copyright 2015 Robert Schroll
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

namespace pdfpc.Renderer {
    /**
     * Cache store
     */
    public class Cache : Object {
        /**
         * In-memory storage for all rendered surfaces
         */
        protected Gee.HashMap<CachedPageProps, CachedPage> storage = null;

        /**
         * Initialize the cache store
         */
        public Cache() {
            this.storage = new Gee.HashMap<CachedPageProps, CachedPage>();
        }

        /**
         * Store a surface in the cache using the (index, width, height) tuple
         * as identifier; also keep the time it took to render
         */
        public void store(CachedPageProps props, Cairo.ImageSurface surface,
            double rtime) {
            CachedPage page = this.storage.get(props);
            if (page == null) {
                page = new CachedPage();
            }

            page.rtime = rtime;

            // Store large images in the compressed (PNG) form
            uint size = 3*props.width*props.height;
            if (size > Options.cache_max_usize) {
                Gdk.Pixbuf pixbuf = Gdk.pixbuf_get_from_surface(surface,
                    0, 0, surface.get_width(), surface.get_height());
                try {
                    pixbuf.save_to_buffer(out page.png_data,
                        "png", "compression", "1", null);
                    page.surface = null;
                    if (Options.cache_debug) {
                        printerr("Compression ratio of [%u] (%ux%u) = %g\n",
                            props.index, props.width, props.height,
                                (double) size/page.png_data.length);
                    }
                } catch (Error e) {
                    GLib.printerr("PNG generation failed for slide %u: %s\n",
                        props.index, e.message);
                    // Store the uncompressed image
                    page.surface = surface;
                    page.png_data = null;
                }
            } else {
                page.surface = surface;
                page.png_data = null;
            }
            this.storage.set(props, page);
        }

        /**
         * Retrieve a stored surface from the cache.
         *
         * If no item with the given (index, width, height) tuple is available,
         * null is returned
         */
        public Cairo.ImageSurface? retrieve(CachedPageProps props) {
            CachedPage page = this.storage.get(props);

            if (page != null) {
                if (page.surface != null) {
                    return page.surface;
                } else {
                    var loader = new Gdk.PixbufLoader();
                    try {
                        loader.write(page.png_data);
                        loader.close();
                    } catch (Error e) {
                        GLib.printerr("PNG loader failed for slide %u: %s\n",
                            props.index, e.message);
                        return null;
                    }
                    var pixbuf = loader.get_pixbuf();
                    Cairo.ImageSurface surface =
                        new Cairo.ImageSurface(Cairo.Format.ARGB32,
                        pixbuf.get_width(), pixbuf.get_height());

                    Cairo.Context cr = new Cairo.Context(surface);
                    Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0);
                    cr.rectangle(0, 0, pixbuf.get_width(), pixbuf.get_height());
                    cr.fill();

                    return surface;
                }
            } else {
                return null;
            }
        }

        /**
         * Invalidate the whole cache (if the document is reloaded/changed)
         */
        public void invalidate() {
            this.storage.clear();
        }
    }

    protected class CachedPageProps : Object, Gee.Hashable<CachedPageProps> {
        public uint index;
        public uint width;
        public uint height;

        public CachedPageProps(uint index, uint width, uint height) {
            this.index  = index;
            this.width  = width;
            this.height = height;
        }

        protected uint hash() {
            return this.index + 1000*(this.width%13 + this.height%17);
        }

        protected bool equal_to(CachedPageProps other) {
            return this.index == other.index &&
                   this.width == other.width &&
                   this.height == other.height;
        }
    }

    public class CachedPage {
        public Cairo.ImageSurface? surface = null;
        public uint8[]? png_data = null;
        public double rtime;
    }
}
