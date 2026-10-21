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
 * the Free Software Foundation; either version 3 of the License, or
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
         * Timeout ID of cache cleaner
         */
        protected uint timeout_id = 0;

        /**
         * Incremented on every invalidation, so that surfaces rendered from
         * an outdated document can be recognized
         */
        public int generation { get; protected set; default = 0; }

        /**
         * Initialize the cache store and launch a periodic cleaning
         */
        public Cache() {
            this.storage = new Gee.HashMap<CachedPageProps, CachedPage>();
            if (Options.cache_expiration > 0) {
                this.timeout_id =
                    GLib.Timeout.add(1000*Options.cache_clean_period,
                        this.clean_cache);
            }
        }

        /**
         * Whether a page of the given size is stored compressed
         */
        public static bool is_compressed_size(int width, int height) {
            uint size = 3*width*height;
            return size/1024 > Options.cache_max_usize;
        }

        /**
         * Compress a surface (as PNG); returns null on failure
         */
        public static uint8[]? compress(Cairo.ImageSurface surface) {
            Gdk.Pixbuf pixbuf = Gdk.pixbuf_get_from_surface(surface,
                0, 0, surface.get_width(), surface.get_height());
            try {
                uint8[] data;
                pixbuf.save_to_buffer(out data,
                    "png", "compression", "1", null);
                return data;
            } catch (Error e) {
                GLib.printerr("PNG generation failed: %s\n", e.message);
                return null;
            }
        }

        /**
         * Store a surface in the cache using the (index, width, height) tuple
         * as identifier; also keep the time it took to render.
         *
         * Large surfaces are stored compressed; png_data is used if given
         * (e.g., compressed by the render helper already).
         */
        public void store(CachedPageProps props, Cairo.ImageSurface surface,
            bool permanent, GLib.Bytes? png_data = null) {
            var page = new CachedPage();
            page.permanent = permanent;
            page.atime = GLib.get_monotonic_time();
            page.surface = surface;

            if (is_compressed_size((int) props.width, (int) props.height)) {
                GLib.Bytes? png = png_data;
                if (png == null) {
                    var data = compress(surface);
                    if (data != null) {
                        png = new GLib.Bytes.take((owned) data);
                    }
                }
                // Otherwise, store the uncompressed image
                if (png != null) {
                    page.png_data = png;
                    page.surface = null;
                    if (Options.cache_debug) {
                        printerr("Compression ratio of [%u] (%ux%u) = %g\n",
                            props.index, props.width, props.height,
                            3.0*props.width*props.height/png.length);
                    }
                }
            }

            this.storage.set(props, page);
        }

        /**
         * Check whether an item with the given (index, width, height) tuple
         * is available, without decompressing it
         */
        public bool contains(CachedPageProps props) {
            return this.storage.has_key(props);
        }

        /**
         * Retrieve a stored surface from the cache.
         *
         * If no item with the given (index, width, height) tuple is available,
         * null is returned
         */
        public Cairo.ImageSurface? retrieve(CachedPageProps props) {
            CachedPage page = this.storage.get(props);
            if (page == null) {
                return null;
            }

            page.atime = GLib.get_monotonic_time();
            return this.unpack(page, props.index);
        }

        /**
         * Retrieve a stored surface of the given slide in another size of
         * the same aspect ratio, to be scaled and shown while the slide is
         * rendered at the proper size. Prefers the smallest one not smaller
         * than requested, otherwise the largest one. Compressed ones are
         * not considered, decompressing could take longer than rendering.
         * Returns null if there is none.
         */
        public Cairo.ImageSurface? retrieve_any_size(uint index,
            bool notes_area, int width, int height) {
            CachedPage best = null;
            uint best_width = 0;
            var it = this.storage.map_iterator();
            while (it.next()) {
                var props = it.get_key();
                if (props.index != index || props.notes_area != notes_area ||
                    it.get_value().surface == null) {
                    continue;
                }

                // Same aspect ratio within 1%
                double ratio = (double) props.width/props.height;
                double target_ratio = (double) width/height;
                if ((ratio - target_ratio).abs() > 0.01*target_ratio) {
                    continue;
                }

                bool better;
                if (best == null) {
                    better = true;
                } else if (best_width >= width) {
                    better = props.width >= width && props.width < best_width;
                } else {
                    better = props.width > best_width;
                }
                if (better) {
                    best = it.get_value();
                    best_width = props.width;
                }
            }

            if (best == null) {
                return null;
            }
            return best.surface;
        }

        /**
         * Return the surface of a cached page, decompressing it if needed
         */
        protected Cairo.ImageSurface? unpack(CachedPage page, uint index) {
            if (page.surface != null) {
                return page.surface;
            }

            var loader = new Gdk.PixbufLoader();
            try {
                loader.write_bytes(page.png_data);
                loader.close();
            } catch (Error e) {
                GLib.printerr("PNG loader failed for slide %u: %s\n",
                    index, e.message);
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

        /**
         * Invalidate the whole cache (if the document is reloaded/changed)
         */
        public void invalidate() {
            this.generation++;
            this.storage.clear();
        }

        /**
         * Evict expired cached slides
         */
        public bool clean_cache() {
            var current_time = GLib.get_monotonic_time();

            var it = this.storage.map_iterator();
            while (it.has_next()) {
                it.next();
                var cpage = it.get_value();

                // check for expired pages, but keep very "precious" ones
                // in any case
                if ((current_time - cpage.atime)/1000000L >
                    Options.cache_expiration && !cpage.permanent) {
                    if (Options.cache_debug) {
                        var props = it.get_key();
                        stdout.printf("Expired cache of [%u] %ux%u\n",
                            props.index, props.width, props.height);
                    }
                    it.unset();
                }
            }
            return GLib.Source.CONTINUE;
        }
    }

    protected class CachedPageProps : Object, Gee.Hashable<CachedPageProps> {
        public uint index;
        public uint width;
        public uint height;
        public bool notes_area;

        public CachedPageProps(uint index, uint width, uint height, bool notes_area) {
            this.index      = index;
            this.width      = width;
            this.height     = height;
            this.notes_area = notes_area;
        }

        protected uint hash() {
            return this.index + 1000*(this.width%13 + this.height%17);
        }

        protected bool equal_to(CachedPageProps other) {
            return this.index      == other.index  &&
                   this.width      == other.width  &&
                   this.height     == other.height &&
                   this.notes_area == other.notes_area;
        }
    }

    public class CachedPage {
        /**
         * The rendered raster image
         */
        public Cairo.ImageSurface? surface = null;

        /**
         * The compressed image data (PNG)
         */
        public GLib.Bytes? png_data = null;

        /**
         * Whether to keep it permanently
         */
        public bool permanent = false;

        /**
         * Last access timestamp (microseconds)
         */
        public int64 atime = 0;
    }
}
