/**
 * Pdf renderer
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2012, 2015 Andreas Bilke
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

namespace pdfpc {
    /**
     * Called with the result of an asynchronous render; surface is null if
     * the slide could not be rendered
     */
    public delegate void Renderer.RenderCallback(Cairo.ImageSurface? surface);

    /**
     * Priority of asynchronous render requests
     */
    public enum Renderer.Priority {
        /**
         * Slides being displayed
         */
        HIGH,
        /**
         * Overview thumbnails
         */
        NORMAL,
        /**
         * Pre-rendering of upcoming slides; the result is always cached
         */
        LOW
    }

    /**
     * A queued asynchronous render job
     */
    public class Renderer.Request : Object {
        public int slide_number;
        public bool notes_area;
        public int width;
        public int height;

        public Renderer.Priority priority;

        /**
         * Whether the result may be cached (never for zoomed-in slides)
         */
        public bool cacheable;

        /**
         * Cache the result regardless of its render time, and keep it
         */
        public bool permanent_cache;

        /**
         * Transformation from PDF to surface coordinates
         */
        public double scaling_factor;
        public double x_offset;
        public double y_offset;

        /**
         * Cache generation at the time of the request; the request fails
         * if it changes, i.e., the document gets reloaded
         */
        public int generation;

        public Renderer.RenderCallback? callback;

        /**
         * Key in the renderer's set of queued pre-render requests, if any
         */
        public string? prerender_key;

        /**
         * Cancelled requests are skipped, and their callback isn't called
         */
        public bool cancelled { get; private set; default = false; }

        public void cancel() {
            this.cancelled = true;
        }
    }

    /**
     * Pdf slide renderer
     *
     * Slides can be rendered either synchronously (render()) or
     * asynchronously (request()). Asynchronous requests are queued and
     * rendered one by one in a helper process (see Renderer.Helper), which
     * keeps the UI responsive with slides that are expensive to render. If
     * the helper is not available, they are rendered in-process, one per
     * main loop iteration.
     *
     * Everything here runs on the main thread.
     */
    public class Renderer.Pdf : Object {
        /**
         * Metadata object to render slides for
         */
        public Metadata.Pdf metadata { get; protected set; }

        /**
         * Cache store to be used
         */
        protected Renderer.Cache cache { get; set; }

        /**
         * Pending asynchronous requests
         */
        protected Gee.Deque<Renderer.Request> high_queue =
            new Gee.ArrayQueue<Renderer.Request>();
        protected Gee.Deque<Renderer.Request> normal_queue =
            new Gee.ArrayQueue<Renderer.Request>();
        protected Gee.Deque<Renderer.Request> low_queue =
            new Gee.ArrayQueue<Renderer.Request>();

        /**
         * Whether the queues are being processed
         */
        protected bool dispatching = false;

        /**
         * The helper process rendering the current document, if any
         */
        protected Renderer.Helper? helper = null;

        /**
         * The PDF file as opened together with the document, passed to the
         * helpers; -1 if not open
         */
        protected int document_fd = -1;

        /**
         * Whether helpers can't be used, so that slides are rendered
         * in-process
         */
        protected bool in_process = false;

        /**
         * Keys of the queued requests without callback (i.e., pre-render
         * requests), to avoid queueing them more than once
         */
        protected Gee.HashSet<string> queued_prerenders =
            new Gee.HashSet<string>();

        /**
         * Base constructor taking a pdf metadata object as well as the desired
         * render width and height as parameters.
         *
         * The pdf will always be rendered to fill up all available space. If
         * the proportions of the rendersize do not fit the proportions of the
         * pdf document the renderspace is filled up completely cutting of a
         * part of the pdf document.
         */
        public Pdf(Metadata.Pdf metadata) {
            this.metadata = metadata;

            this.cache = new Renderer.Cache();
            this.start_helper();
        }

        /**
         * (Re)start the helper process for the current document; to be
         * called right after the document has been (re)loaded, so that both
         * see the same file
         */
        protected void start_helper() {
            if (this.helper != null) {
                this.helper.terminate();
                this.helper = null;
            }

            this.in_process = !Renderer.Helper.is_supported();
#if !WIN32
            if (this.document_fd >= 0) {
                Posix.close(this.document_fd);
                this.document_fd = -1;
            }

            var uri = this.metadata.get_url();
            if (this.in_process || uri == null) {
                return;
            }

            var path = File.new_for_uri(uri).get_path();
            this.document_fd = Posix.open(path, Posix.O_RDONLY);
            if (this.document_fd < 0) {
                GLib.printerr("Unable to open %s for rendering: %s\n",
                    path, GLib.strerror(GLib.errno));
                this.in_process = true;
                return;
            }

            this.get_helper();
#endif
        }

        /**
         * Return a running helper, starting one if needed; null if helpers
         * can't be used
         */
        protected Renderer.Helper? get_helper() {
            if (this.in_process) {
                return null;
            }

            if (this.helper == null || this.helper.dead) {
                try {
                    this.helper = new Renderer.Helper(this.document_fd);
                } catch (GLib.Error e) {
                    GLib.printerr("Unable to start the render helper, " +
                        "rendering in-process: %s\n", e.message);
                    this.helper = null;
                    this.in_process = true;
                }
            }

            return this.helper;
        }

        /**
         * Render the given slide_number to a Cairo.ImageSurface and return it.
         *
         * If the requested slide is not available an
         * RenderError.SLIDE_DOES_NOT_EXIST error is thrown.
         */
        public Cairo.ImageSurface render(int slide_number,
            bool notes_area, int width, int height,
            bool force_cache = false, bool permanent_cache = false,
            PresentationController.ScaledRectangle? zoom_area = null)
            throws Renderer.RenderError {

            this.check_slide_number(slide_number);

            CachedPageProps props = null;

            // We never cache a zoomed-in slide
            if (zoom_area == null) {
                props = new CachedPageProps(slide_number,
                    width, height, notes_area);

                // Check for the page in the cache
                Cairo.ImageSurface cache_content;
                if ((cache_content = this.cache.retrieve(props)) != null) {
                    return cache_content;
                }
            }

            double scaling_factor, x_offset, y_offset;
            this.get_transformation(slide_number, notes_area, width, height,
                zoom_area, out scaling_factor, out x_offset, out y_offset);

            var page = this.metadata.document.get_page(slide_number);
            double rtime;
            var surface = render_page(page, width, height,
                scaling_factor, x_offset, y_offset, out rtime);

            this.store_rendered(props, surface, rtime, force_cache,
                permanent_cache);

            return surface;
        }

        /**
         * Return the given slide from the cache, or null if it's not
         * available in the requested size
         */
        public Cairo.ImageSurface? lookup(int slide_number, bool notes_area,
            int width, int height,
            PresentationController.ScaledRectangle? zoom_area = null) {
            if (zoom_area != null) {
                return null;
            }
            return this.cache.retrieve(new CachedPageProps(slide_number,
                width, height, notes_area));
        }

        /**
         * Return the given slide from the cache in another size of the same
         * aspect ratio (to be used as a scaled stand-in while rendering), or
         * null if it's not available
         */
        public Cairo.ImageSurface? lookup_any_size(int slide_number,
            bool notes_area, int width, int height) {
            return this.cache.retrieve_any_size(slide_number, notes_area,
                width, height);
        }

        /**
         * Queue the given slide for rendering. Unless cancelled, callback is
         * invoked from the main loop with the result.
         *
         * Requests are processed by priority, then in order. The result of
         * LOW priority requests is always cached; without a callback, if the
         * slide is already cached, null is returned.
         * With permanent_cache, the result is always cached and kept.
         */
        public Renderer.Request? request(int slide_number, bool notes_area,
            int width, int height, Renderer.Priority priority,
            PresentationController.ScaledRectangle? zoom_area,
            owned Renderer.RenderCallback? callback,
            bool permanent_cache = false)
            throws Renderer.RenderError {

            this.check_slide_number(slide_number);

            string? prerender_key = null;
            if (priority == Renderer.Priority.LOW && callback == null &&
                zoom_area == null) {
                if (this.cache.contains(new CachedPageProps(slide_number,
                    width, height, notes_area))) {
                    return null;
                }
                prerender_key =
                    @"$slide_number:$(width)x$height:$notes_area";
                if (!this.queued_prerenders.add(prerender_key)) {
                    // Queued already
                    return null;
                }
            }

            var req = new Renderer.Request();
            req.slide_number = slide_number;
            req.notes_area = notes_area;
            req.width = width;
            req.height = height;
            req.priority = priority;
            req.cacheable = (zoom_area == null);
            req.permanent_cache = permanent_cache;
            req.callback = (owned) callback;
            req.generation = this.cache.generation;
            req.prerender_key = prerender_key;
            this.get_transformation(slide_number, notes_area, width, height,
                zoom_area, out req.scaling_factor, out req.x_offset,
                out req.y_offset);

            switch (priority) {
            case Renderer.Priority.HIGH:
                this.high_queue.offer_tail(req);
                break;
            case Renderer.Priority.NORMAL:
                this.normal_queue.offer_tail(req);
                break;
            default:
                this.low_queue.offer_tail(req);
                break;
            }

            if (!this.dispatching) {
                this.dispatching = true;
                // Never call back from within request()
                GLib.Idle.add(() => {
                        this.dispatch.begin();
                        return GLib.Source.REMOVE;
                    });
            }

            return req;
        }

        /**
         * Process the queued requests one by one, high priority first
         */
        private async void dispatch() {
            while (true) {
                var req = this.high_queue.poll_head();
                if (req == null) {
                    req = this.normal_queue.poll_head();
                }
                if (req == null) {
                    req = this.low_queue.poll_head();
                }
                if (req == null) {
                    break;
                }
                if (req.prerender_key != null) {
                    this.queued_prerenders.remove(req.prerender_key);
                }
                if (!req.cancelled) {
                    yield this.process_request(req);
                }
            }
            this.dispatching = false;
        }

        /**
         * Execute a single request
         */
        private async void process_request(Renderer.Request req) {
            // The document has been reloaded meanwhile
            if (req.generation != this.cache.generation) {
                this.deliver(req, null);
                return;
            }

            CachedPageProps props = null;
            if (req.cacheable) {
                props = new CachedPageProps(req.slide_number,
                    req.width, req.height, req.notes_area);
                if (req.callback == null) {
                    // Requested by someone else in the meantime
                    if (this.cache.contains(props)) {
                        return;
                    }
                } else {
                    var cached = this.cache.retrieve(props);
                    if (cached != null) {
                        this.deliver(req, cached);
                        return;
                    }
                }
            }

            bool force_cache = req.priority == Renderer.Priority.LOW ||
                req.permanent_cache;

            // Have the helper compress the page for the cache, if it is
            // going to be stored compressed
            var compress = Renderer.HelperCompress.NEVER;
            if (props != null &&
                Renderer.Cache.is_compressed_size(req.width, req.height)) {
                compress = force_cache ? Renderer.HelperCompress.ALWAYS :
                    Renderer.HelperCompress.IF_SLOW;
            }

            Cairo.ImageSurface? surface = null;
            GLib.Bytes? png_data = null;
            double rtime = 0;
            bool rendered = false;

            // If the helper fails (e.g., crashes on this page), try again
            // once with a fresh one, but never render in-process then: what
            // crashed the helper would crash pdfpc
            for (int attempt = 0; attempt < 2 && !rendered; attempt++) {
                var helper = this.get_helper();
                if (helper == null) {
                    break;
                }
                try {
                    surface = yield helper.render(req.slide_number,
                        req.width, req.height, req.scaling_factor,
                        req.x_offset, req.y_offset, compress,
                        Options.cache_min_rtime/1000.0,
                        out rtime, out png_data);
                    rendered = true;
                } catch (GLib.Error e) {
                    if (req.generation != this.cache.generation) {
                        // Terminated because of a reload
                        break;
                    }
                    if (helper.timed_out) {
                        GLib.printerr("Rendering page %d timed out\n",
                            req.slide_number);
                        break;
                    }
                    GLib.printerr("Render helper failed on page %d: %s\n",
                        req.slide_number, e.message);
                }
            }

            if (req.generation != this.cache.generation) {
                this.deliver(req, null);
                return;
            }

            if (!rendered && this.in_process) {
                // Render in-process; let the main loop run first, so that
                // the UI gets updated between consecutive renders
                GLib.Idle.add(this.process_request.callback);
                yield;
                if (req.cancelled || req.generation != this.cache.generation) {
                    this.deliver(req, null);
                    return;
                }

                var page = this.metadata.document.get_page(req.slide_number);
                if (page != null) {
                    surface = render_page(page, req.width, req.height,
                        req.scaling_factor, req.x_offset, req.y_offset,
                        out rtime);
                }
            }

            if (surface != null) {
                this.store_rendered(props, surface, rtime, force_cache,
                    req.permanent_cache, png_data);
            }

            this.deliver(req, surface);
        }

        /**
         * Pass the result of a request to its callback
         */
        private void deliver(Renderer.Request req, Cairo.ImageSurface? surface) {
            if (req.callback != null && !req.cancelled) {
                req.callback(surface);
            }
        }

        protected void check_slide_number(int slide_number)
            throws Renderer.RenderError {
            if (slide_number < 0 ||
                slide_number >= this.metadata.get_slide_count()) {
                throw new Renderer.RenderError.SLIDE_DOES_NOT_EXIST(
                    "The requested slide '%i' does not exist.", slide_number);
            }
        }

        /**
         * Calculate the scaling factor and the offsets to render the given
         * slide into a surface of the given size
         */
        protected void get_transformation(int slide_number, bool notes_area,
            int width, int height,
            PresentationController.ScaledRectangle? zoom_area,
            out double scaling_factor, out double x_offset,
            out double y_offset) {
            var metadata = this.metadata;
            var page = metadata.document.get_page(slide_number);

            // Calculate the scaling factor and the offsets for centering
            double full_page_width, corrected_page_width, full_page_height, corrected_page_height;
            page.get_size(out full_page_width, out full_page_height);
            corrected_page_width = metadata.get_corrected_page_width(full_page_width);
            corrected_page_height = metadata.get_corrected_page_height(full_page_height);

            double h_offset, v_offset;
            if (width/corrected_page_width < height/corrected_page_height) {
                scaling_factor = width/corrected_page_width;
                h_offset = 0;
                v_offset = (height/scaling_factor - corrected_page_height)/2;
            } else {
                scaling_factor = height/corrected_page_height;
                h_offset = (width/scaling_factor - corrected_page_width)/2;
                v_offset = 0;
            }

            if (zoom_area != null) {
                double zoom, h_zoom_offset, v_zoom_offset;
                if (zoom_area.width > zoom_area.height) {
                    zoom = 1/zoom_area.width;
                    h_zoom_offset = 0;
                    v_zoom_offset = (zoom_area.width - zoom_area.height)/2;
                } else {
                    zoom = 1/zoom_area.height;
                    h_zoom_offset = (zoom_area.height - zoom_area.width)/2;
                    v_zoom_offset = 0;
                }
                h_offset -= corrected_page_width*(zoom_area.x - h_zoom_offset);
                v_offset -= corrected_page_height*(zoom_area.y - v_zoom_offset);

                scaling_factor *= zoom;
            }

            x_offset = -metadata.get_horizontal_offset(notes_area, full_page_width) + h_offset;
            y_offset = -metadata.get_vertical_offset(notes_area, full_page_height) + v_offset;
        }

        /**
         * Render a page into a new surface; rtime is the time it took [s]
         */
        public static Cairo.ImageSurface render_page(Poppler.Page page,
            int width, int height,
            double scaling_factor, double x_offset, double y_offset,
            out double rtime) {
            // A lot of Pdfs have transparent backgrounds defined. We render
            // every page before a white background because of this.
            Cairo.ImageSurface surface =
                new Cairo.ImageSurface(Cairo.Format.RGB24, width, height);
            Cairo.Context cr = new Cairo.Context(surface);

            cr.set_source_rgb(255, 255, 255);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            cr.scale(scaling_factor, scaling_factor);
            cr.translate(x_offset, y_offset);

            GLib.Timer timer = new GLib.Timer();
            page.render(cr);
            timer.stop();
            rtime = timer.elapsed();

            return surface;
        }

        /**
         * Store a freshly rendered page in the cache, if it has taken a
         * significant time to render. props is null for zoomed-in slides,
         * which are never cached.
         */
        protected void store_rendered(CachedPageProps? props,
            Cairo.ImageSurface surface, double rtime, bool force_cache,
            bool permanent_cache, GLib.Bytes? png_data = null) {
            if (Options.cache_debug && props != null) {
                printerr("Render time of [%u] (%ux%u) = %g s\n",
                    props.index, props.width, props.height, rtime);
            }

            if (props != null &&
                (force_cache || rtime > Options.cache_min_rtime/1000.0)) {
                // keep very "precious" slides permanently
                if (rtime > Options.cache_max_rtime/1000.0) {
                    permanent_cache = true;
                }
                this.cache.store(props, surface, permanent_cache, png_data);
            }
        }

        public Cairo.ImageSurface fade_to_black(int width, int height) {
            Cairo.ImageSurface surface =
                new Cairo.ImageSurface(Cairo.Format.RGB24, width, height);
            Cairo.Context cr = new Cairo.Context(surface);

            cr.set_source_rgb(0, 0, 0);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            double scaling_factor = Math.fmax(width/metadata.get_page_width(),
                height/metadata.get_page_height());
            cr.scale(scaling_factor, scaling_factor);

            return surface;
        }

        /**
         * Invalidate the whole cache (if the document is reloaded/changed);
         * pending requests fail
         */
        public void invalidate_cache() {
            this.cache.invalidate();
            this.start_helper();
        }
    }

    /**
     * Error domain used for every render error, which might occur
     */
    public errordomain Renderer.RenderError {
        SLIDE_DOES_NOT_EXIST;
    }
}
