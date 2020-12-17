/**
 * Spezialized Pdf View
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2011-2012 David Vilar
 * Copyright 2012, 2015, 2017 Andreas Bilke
 * Copyright 2012, 2015 Robert Schroll
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
     * View spezialized to work with Pdf renderers.
     *
     * This class is mainly needed to be decorated with pdf-link-interactions
     * signals.
     *
     * By default it does not implement any further functionality.
     */
    public class View.Pdf : Gtk.DrawingArea {
        /**
         * Signal fired every time a slide is about to be left
         */
        public signal void leaving_slide(int from, int to);

        /**
         * Signal fired every time a slide is fully entered (i.e, the
         * transition animation, if defined, is over)
         */
        public signal void entering_slide(int slide_number);

        /**
         * Flag that the entering_slide signal is queued
         */
        protected bool entering_slide_queued = false;

        /**
         * Renderer to be used for rendering the slides
         */
        protected Renderer.Pdf renderer;

        /**
         * Return the metadata object
         */
        public Metadata.Pdf get_metadata() {
            return this.renderer.metadata;
        }

        /**
         * Signal emitted on toggling the freeze state
         */
        public signal void freeze_toggled(bool frozen);

        /**
         * The currently displayed slide number
         */
        protected int current_slide_number;

        /**
         * and its rendered image
         */
        protected Cairo.ImageSurface current_slide;

        /**
         * Blit buffer
         */
        protected Cairo.ImageSurface buffer;

        /**
         * Whether the view should remain black
         */
        public bool disabled;

        /**
         * Whether the view will show only full user slides (without
         * intermediate overlays)
         */
        public bool user_slides;

        /**
         * The number of slides in the presentation
         */
        protected int n_slides {
            get {
                return (int) this.get_metadata().get_slide_count();
            }
        }

        /**
         * List to store all associated behaviours
         */
        protected GLib.List<View.Behaviour.Base> behaviours = new GLib.List<View.Behaviour.Base>();

        /**
         * GDK scale factor
         */
        protected int gdk_scale = 1;

        /**
         * Whether the PDF area to be displayed is (beamer) notes
         */
        protected bool notes_area;

        /**
         * ID of timeout used to delay pre-rendering
         */
        protected uint prerender_tid = 0;

        /**
         * Transition timer
         */
        protected uint transition_tid = 0;

        public bool transitions_enabled = false;

        /**
         * Zoom area
         */
        protected PresentationController.ScaledRectangle? zoom_area = null;

        /**
         * Launch pre-rendering
         */
        protected virtual bool prerender() {
            // indicate we're running, too late to cancel even if desired
            this.prerender_tid = 0;

            // things might have changed during prerender_delay...
            if (this.disabled) {
                return GLib.Source.REMOVE;
            }

            // The pointer is needed to keep track of the slide progress inside
            // the pre-render loop
            int* p_slide = null;

            int first_page = this.current_slide_number + 1;
            if (first_page >= this.n_slides) {
                // nothing to pre-render
                return GLib.Source.REMOVE;
            }

            var metadata = this.get_metadata();

            int last_slide;
            if (this.user_slides) {
                var user_slide = metadata.real_slide_to_user_slide(this.current_slide_number);
                var last_user_slide = user_slide + Options.prerender_slides;
                last_slide = metadata.user_slide_to_real_slide(last_user_slide, true);
            } else {
                last_slide = this.current_slide_number + Options.prerender_slides;
            }
            if (last_slide >= this.n_slides) {
                last_slide = this.n_slides - 1;
            }

            int width, height;
            this.get_pixel_dimensions(out width, out height);

            GLib.Idle.add(() => {
                if (p_slide == null) {
                    p_slide = malloc(sizeof(int));
                    *p_slide = first_page;
                }

                if (!this.user_slides || metadata.is_user_slide(*p_slide)) {
                    // We do not care about the result, as the
                    // rendering function stores the rendered
                    // pixmap in the cache if it is enabled. This
                    // is exactly what we want.
                    try {
                        this.renderer.render(*p_slide, this.notes_area, width, height,
                            true);
                    } catch(Renderer.RenderError e) {
                        GLib.printerr("Could pre-render page '%i': %s\n",
                            *p_slide, e.message);
                    }
                }

                // Increment one slide for each call and stop the loop if we
                // have reached the last slide
                *p_slide = *p_slide + 1;
                if (*p_slide > last_slide) {
                    free(p_slide);
                    return GLib.Source.REMOVE;
                } else {
                    return GLib.Source.CONTINUE;
                }
            });

            // don't repeat...
            return GLib.Source.REMOVE;
        }

        /**
         * Default constructor restricted to Pdf renderers as input parameter
         */
        protected Pdf(Renderer.Pdf renderer, bool notes_area,
            bool clickable_links, PresentationController controller,
            int gdk_scale_factor, bool user_slides) {
            this.renderer = renderer;
            this.gdk_scale = gdk_scale_factor;
            this.notes_area = notes_area;
            this.user_slides = user_slides;

            this.current_slide_number = -1;

            this.add_events(Gdk.EventMask.STRUCTURE_MASK);

            if (clickable_links) {
                // Enable the PDFLink Behaviour by default on PDF Views
                this.associate_behaviour(new View.Behaviour.PdfLink());
            }
        }

        /**
         * Create a new Pdf view from a Fullscreen window instance
         *
         * This is a convenience constructor which automatically creates a full
         * metadata and rendering chain to be used with the pdf view.
         */
        public Pdf.from_fullscreen(Window.Fullscreen window,
            bool notes_area, bool clickable_links, bool user_slides=false) {
            var controller = window.controller;
            var metadata = controller.metadata;

            var renderer = metadata.renderer;

            this(renderer, notes_area, clickable_links, controller, window.gdk_scale,
                user_slides);
        }

        /**
         * Convert an arbitrary Poppler.Rectangle struct into a Gdk.Rectangle
         * struct taking into account the measurement differences between pdf
         * space and screen space.
         */
        public Gdk.Rectangle convert_poppler_rectangle_to_gdk_rectangle(
            Poppler.Rectangle poppler_rectangle) {
            Gdk.Rectangle gdk_rectangle = Gdk.Rectangle();

            Gtk.Allocation allocation;
            this.get_allocation(out allocation);

            // We need the page dimensions for coordinate conversion between
            // pdf coordinates and screen coordinates
            var metadata = this.get_metadata();
            gdk_rectangle.x = (int) Math.ceil((poppler_rectangle.x1 / metadata.get_page_width()) *
                allocation.width );
            gdk_rectangle.width = (int) Math.floor(((poppler_rectangle.x2 - poppler_rectangle.x1) /
                metadata.get_page_width()) * allocation.width);

            // Gdk has its coordinate origin in the upper left, while Poppler
            // has its origin in the lower left.
            gdk_rectangle.y = (int) Math.ceil(((metadata.get_page_height() - poppler_rectangle.y2) /
                metadata.get_page_height()) * allocation.height);
            gdk_rectangle.height = (int) Math.floor(((poppler_rectangle.y2 - poppler_rectangle.y1) /
                metadata.get_page_height()) * allocation.height);

            return gdk_rectangle;
        }

        /**
         * Associate a new Behaviour with this View
         *
         * The implementation supports an arbitrary amount of different
         * behaviours.
         */
        public void associate_behaviour(Behaviour.Base behaviour) {
            this.behaviours.append(behaviour);
            try {
                behaviour.associate(this);
            } catch(Behaviour.AssociationError e) {
                GLib.printerr("Behaviour association failure: %s\n", e.message);
                Process.exit(1);
            }
        }

        /**
         * Display a specific slide number, optionally zooming in a
         * rectangular area
         */
        public void display(int slide_number, bool force = false,
            PresentationController.ScaledRectangle? rect = null) {
            if (this.n_slides == 0) {
                return;
            }

            if (this.current_slide_number != slide_number || force) {
                int width, height;
                this.get_pixel_dimensions(out width, out height);
                // not ready yet
                if (height <= 1 || width <= 1) {
                    return;
                }

                bool trans_inverse = false;
                bool sequential_move = false;
                if (slide_number == this.current_slide_number + 1) {
                    sequential_move = true;
                } else if (slide_number + 1 == this.current_slide_number) {
                    sequential_move = true;
                    trans_inverse = true;
                }
                int trans_slide_number;
                if (trans_inverse) {
                    trans_slide_number = this.current_slide_number;
                } else {
                    trans_slide_number = slide_number;
                }

                // Notify all listeners
                this.leaving_slide(this.current_slide_number, slide_number);

                this.current_slide_number = slide_number;

                this.zoom_area = rect;

                // Cancel any active transition timeout
                if (this.transition_tid != 0) {
                    GLib.Source.remove(this.transition_tid);
                    this.transition_tid = 0;
                }

                // Save the previous slide for transition
                var previous_slide = this.current_slide;

                try {
                    if (this.current_slide_number < this.n_slides &&
                        !this.disabled) {
                        this.current_slide =
                            this.renderer.render(this.current_slide_number,
                                this.notes_area, width, height,
                                false, false, this.zoom_area);

                        if (Options.prerender_slides != 0) {
                            // cancel any pending pre-rendering
                            if (this.prerender_tid != 0) {
                                GLib.Source.remove(this.prerender_tid);
                            }

                            // wait before starting pre-rendering
                            this.prerender_tid =
                                GLib.Timeout.add(1000*Options.prerender_delay,
                                    this.prerender);
                        }
                    } else {
                        this.current_slide =
                            this.renderer.fade_to_black(width, height);
                    }
                } catch (Renderer.RenderError e) {
                    GLib.printerr("The pdf page %d could not be rendered: %s\n",
                        this.current_slide_number, e.message);
                    return;
                }

                // The transition manager object
                View.TransitionManager transman = null;

                if (!this.disabled && this.transitions_enabled &&
                    sequential_move && previous_slide != null) {
                    var metadata = this.get_metadata();
                    transman = new View.TransitionManager(metadata,
                        trans_slide_number, previous_slide, this.current_slide,
                        trans_inverse);
                }

                if (transman == null || !transman.is_enabled) {
                    // Just the new slide
                    this.buffer = this.current_slide;

                    // Queue the signal
                    this.entering_slide_queued = true;

                    // Update the widget
                    this.queue_draw();
                } else {
                    this.buffer = new Cairo.ImageSurface(Cairo.Format.RGB24,
                        width, height);
                    Cairo.Context buffer_cr = new Cairo.Context(this.buffer);

                    var delay = transman.frame_duration;
                    this.transition_tid = Timeout.add(delay, () => {
                            var inprogress = transman.advance();

                            // Ensure no active clipping from the previous frame
                            buffer_cr.reset_clip();
                            transman.draw_frame(buffer_cr);

                            if (!inprogress) {
                                // Queue the signal _prior_ to the final draw()
                                this.entering_slide_queued = true;
                            }

                            this.queue_draw();

                            if (inprogress) {
                                return true;
                            } else {
                                this.transition_tid = 0;
                                // Stop the timer
                                return false;
                            }
                        }, Priority.HIGH);
                }
            }
        }

        /**
         * Invalidate the current slide, forcing redrawing on update
         */
        public void invalidate() {
            this.current_slide_number = -1;
            this.current_slide = null;
        }

        /**
         * Return pixel dimensions of the widget
         */
        protected void get_pixel_dimensions(out int width, out int height) {
            Gtk.Allocation allocation;
            this.get_allocation(out allocation);
            width = allocation.width*this.gdk_scale;
            height = allocation.height*this.gdk_scale;
        }

        /**
         * This method is called by Gdk every time the widget needs to be redrawn.
         *
         * The implementation does a simple blit from the internal pixmap to
         * the window surface.
         */
        protected override bool draw(Cairo.Context cr) {
            // not ready yet
            if (this.buffer == null) {
                return true;
            }

            int width, height;
            this.get_pixel_dimensions(out width, out height);
            // Re-render the slide on resize events
            if (width  != this.buffer.get_width() ||
                height != this.buffer.get_height()) {
                try {
                    this.buffer =
                        this.renderer.render(this.current_slide_number,
                            this.notes_area, width, height,
                            false, false, this.zoom_area);
                } catch (Renderer.RenderError e) {
                    return true;
                }
            }

            cr.scale((1.0/this.gdk_scale), (1.0/this.gdk_scale));
            cr.set_source_surface(this.buffer, 0, 0);
            cr.paint();

            if (this.entering_slide_queued) {
                this.entering_slide_queued = false;
                // At this point, the transition to the new slide is over;
                // notify the listeners
                this.entering_slide(this.current_slide_number);
            }

            // We are the only ones drawing on this context; skip everything else
            return true;
        }
    }
}
