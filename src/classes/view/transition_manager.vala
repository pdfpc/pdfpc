/**
 * Pdf page transitions
 *
 * This file is part of pdfpc.
 *
 * Copyright 2020 Evgeny Stambulchik
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
     * Handle PDF slide transition
     */
    public class View.TransitionManager : Object {
        protected Poppler.PageTransition transition = null;

        protected uint fps;

        /**
         * Number of frames in the transition
         */
        protected uint nframes;

        /**
         * Internal frame counter
         */
        protected uint iframe = 0;

        /**
         * Slides to transition between
         */
        protected Cairo.ImageSurface prev;
        protected Cairo.ImageSurface next;

        /**
         * Dimensions of the slide
         */
        protected int width = 0;
        protected int height = 0;

        /**
         * The constructor
         */
        public TransitionManager(Metadata.Pdf metadata, int slide_number,
            Cairo.ImageSurface prev, Cairo.ImageSurface next, bool inverse) {

            this.fps = Options.transition_fps;
            this.iframe = 0;
            this.prev = prev;
            this.next = next;
            this.transition = null;

            this.width  = prev.get_width();
            this.height = prev.get_height();

            if (this.fps > 0 &&
                slide_number >= 0 &&
                slide_number < metadata.get_slide_count()) {
                var page = metadata.get_document().get_page(slide_number);

                var trans = page.get_transition();
                // If undefined or is the simple replace transition, assume the
                // user-defined one
                if (trans == null ||
                    trans.type == Poppler.PageTransitionType.REPLACE) {
                    trans = metadata.default_transition;
                }

                trans.angle %= 360;
                if (trans.angle % 90 != 0) {
                    GLib.printerr("Diagonal transitions are unsupported.\n");
                    this.transition = null;
                }

                switch (trans.type) {
                case Poppler.PageTransitionType.REPLACE:
                    // Not really a transition
                    this.transition = null;
                    break;
                case Poppler.PageTransitionType.FLY:
                    // Not supported yet
                    GLib.printerr("Fly page transition is unsupported.\n");
                    this.transition = null;
                    break;
                default:
                    this.transition = trans;
                    break;
                }

                // For inverse transitions, "fix" the properties and/or type
                if (inverse && this.transition != null) {
                    switch (this.transition.type) {
                    case Poppler.PageTransitionType.COVER:
                        this.transition.type = Poppler.PageTransitionType.UNCOVER;
                        break;
                    case Poppler.PageTransitionType.UNCOVER:
                        this.transition.type = Poppler.PageTransitionType.COVER;
                        break;
                    }

                    this.transition.angle = (180 + this.transition.angle)%360;

                    switch (this.transition.direction) {
                    case Poppler.PageTransitionDirection.INWARD:
                        this.transition.direction =
                            Poppler.PageTransitionDirection.OUTWARD;
                        break;
                    case Poppler.PageTransitionDirection.OUTWARD:
                        this.transition.direction =
                            Poppler.PageTransitionDirection.INWARD;
                        break;
                    }
                }
            }

            if (this.transition != null) {
                this.nframes =
                    (uint) Math.ceil(this.transition.duration_real*this.fps);
            }
        }

        public bool is_enabled {
            get {
                if (this.prev != null && this.next != null &&
                    this.transition != null) {
                    return true;
                } else {
                    return false;
                }
            }
        }

        public uint frame_duration {
            get {
                if (this.is_enabled) {
                    return (uint) (1000/this.fps);
                } else {
                    return 0;
                }
            }
        }

        /**
         * Advance the transition; return true if not finished and false
         * otherwise
         */
        public bool advance() {
            this.iframe++;
            if (this.iframe >= this.nframes) {
                return false;
            } else {
                return true;
            }
        }

        /**
         * Draw a single transition frame on the context provided.
         * For most of the transitions, first paint one slide, then set a
         * dynamically changing clip region, then paint the other slide.
         */
        public void draw_frame(Cairo.Context cr) {

            if (!this.is_enabled) {
                return;
            }
            // Make sure we're not in the middle of window resize
            if (this.width != next.get_width() ||
                this.height != next.get_height()) {
                return;
            }

            Cairo.ImageSurface slide1, slide2;

            double xshift = 0, yshift = 0;
            double clip_width = width, clip_height = height;

            double progress = (double) this.iframe/this.nframes;

            if (progress > 1.0) {
                progress = 1.0;
            }

            switch (this.transition.type) {
            case Poppler.PageTransitionType.COVER:
                switch (this.transition.angle) {
                case   0:
                    xshift = -width*(1.0 - progress);
                    break;
                case  90:
                    yshift = -height*(1.0 - progress);
                    break;
                case 180:
                    xshift = width*(1.0 - progress);
                    break;
                case 270:
                    yshift = height*(1.0 - progress);
                    break;
                }

                cr.set_source_surface(prev, 0, 0);
                cr.paint();

                cr.set_source_surface(next, xshift, yshift);
                cr.paint();

                break;
            case Poppler.PageTransitionType.UNCOVER:
                switch (this.transition.angle) {
                case   0:
                    xshift = width*progress;
                    break;
                case  90:
                    yshift = height*progress;
                    break;
                case 180:
                    xshift = -width*progress;
                    break;
                case 270:
                    yshift = -height*progress;
                    break;
                }

                cr.set_source_surface(next, 0, 0);
                cr.paint();

                cr.set_source_surface(prev, xshift, yshift);
                cr.paint();

                break;
            case Poppler.PageTransitionType.PUSH:
                double xshift2 = 0, yshift2 = 0;
                switch (this.transition.angle) {
                case   0:
                    xshift = width*progress;
                    xshift2 = xshift - width;
                    break;
                case  90:
                    yshift = height*progress;
                    yshift2 = yshift - height;
                    break;
                case 180:
                    xshift = -width*progress;
                    xshift2 = xshift + width;
                    break;
                case 270:
                    yshift = -height*progress;
                    yshift2 = yshift + height;
                    break;
                }

                cr.set_source_surface(prev, xshift, yshift);
                cr.paint();

                cr.set_source_surface(next, xshift2, yshift2);
                cr.paint();

                break;
            case Poppler.PageTransitionType.DISSOLVE:
                var cell_size = double.min(width, height)/10;
                clip_width = cell_size*progress + 1;
                clip_height = cell_size*progress + 1;

                cr.set_source_surface(prev, 0, 0);
                cr.paint();

                for (int i = 0; i*cell_size < width; i++) {
                    xshift = i*cell_size - clip_width/2;
                    for (int j = 0; j*cell_size < height; j++) {
                        yshift = j*cell_size - clip_height/2;
                        cr.rectangle(xshift, yshift, clip_width, clip_height);
                    }
                }
                cr.clip();

                cr.set_source_surface(next, 0, 0);
                cr.paint();

                break;
            case Poppler.PageTransitionType.FADE:
                cr.set_source_surface(next, 0, 0);
                cr.paint();

                cr.set_source_surface(prev, 0, 0);
                cr.paint_with_alpha(1 - progress);

                break;
            case Poppler.PageTransitionType.BOX:
                if (this.transition.direction ==
                    Poppler.PageTransitionDirection.INWARD) {
                    slide1 = next;
                    slide2 = prev;
                    xshift = 0.5*width*progress;
                    yshift = 0.5*height*progress;
                } else {
                    slide1 = prev;
                    slide2 = next;
                    xshift = 0.5*width*(1 - progress);
                    yshift = 0.5*height*(1 - progress);
                }

                cr.set_source_surface(slide1, 0, 0);
                cr.paint();

                cr.rectangle(xshift, yshift, width - 2*xshift, height - 2*yshift);
                cr.clip();

                cr.set_source_surface(slide2, 0, 0);
                cr.paint();

                break;
            case Poppler.PageTransitionType.GLITTER:
            case Poppler.PageTransitionType.WIPE:
                switch (this.transition.angle) {
                case   0:
                    clip_width = width*progress;
                    break;
                case  90:
                    clip_height = height*progress;
                    break;
                case 180:
                    xshift = width*(1 - progress);
                    clip_width = width*progress;
                    break;
                case 270:
                    yshift = height*(1 - progress);
                    clip_height = height*progress;
                    break;
                }

                cr.set_source_surface(prev, 0, 0);
                cr.paint();

                // Draw the glittering "wave front"
                if (this.transition.type == Poppler.PageTransitionType.GLITTER) {
                    int wave_ncells = 4;
                    double wave_cell_frac = 0.02;

                    var cell_size = double.min(width, height)*wave_cell_frac;

                    double wave_xmin = 0, wave_xmax = width;
                    double wave_ymin = 0, wave_ymax = height;
                    var wave_breadth = cell_size*wave_ncells;
                    switch (this.transition.angle) {
                    case   0:
                        wave_xmin = double.max(clip_width - wave_breadth, 0);
                        wave_xmax = clip_width;
                        clip_width -= wave_breadth;
                        break;
                    case  90:
                        wave_ymin = double.max(clip_height - wave_breadth, 0);
                        wave_ymax = clip_height;
                        clip_height -= wave_breadth;
                        break;
                    case 180:
                        wave_xmin = double.max(xshift - wave_breadth, 0);
                        wave_xmax = xshift;
                        clip_width += wave_breadth;
                        break;
                    case 270:
                        wave_ymin = double.max(yshift - wave_breadth, 0);
                        wave_ymax = yshift;
                        clip_height += wave_breadth;
                        break;
                    }

                    int imin = (int) Math.floor(wave_xmin/cell_size);
                    int imax = (int) Math.floor(wave_xmax/cell_size);
                    int jmin = (int) Math.floor(wave_ymin/cell_size);
                    int jmax = (int) Math.floor(wave_ymax/cell_size);
                    for (int i = imin; i < imax; i++) {
                        for (int j = jmin; j < jmax; j++) {
                            bool onoff = Random.boolean();
                            if (onoff) {
                                cr.rectangle(i*cell_size, j*cell_size,
                                    cell_size, cell_size);
                            }
                        }
                    }
                }

                cr.rectangle(xshift, yshift, clip_width, clip_height);

                cr.clip();

                cr.set_source_surface(next, 0, 0);
                cr.paint();

                break;
            case Poppler.PageTransitionType.SPLIT:
                if (this.transition.alignment ==
                    Poppler.PageTransitionAlignment.VERTICAL) {
                    if (this.transition.direction ==
                        Poppler.PageTransitionDirection.INWARD) {
                        slide1 = next;
                        slide2 = prev;
                        xshift = 0.5*width*progress;
                        clip_width = width*(1 - progress);
                    } else {
                        slide1 = prev;
                        slide2 = next;
                        xshift = 0.5*width*(1 - progress);
                        clip_width = width*progress;
                    }
                } else {
                    if (this.transition.direction ==
                        Poppler.PageTransitionDirection.INWARD) {
                        slide1 = next;
                        slide2 = prev;
                        yshift = 0.5*height*progress;
                        clip_height = height*(1 - progress);
                    } else {
                        slide1 = prev;
                        slide2 = next;
                        yshift = 0.5*height*(1 - progress);
                        clip_height = height*progress;
                    }
                }

                cr.set_source_surface(slide1, 0, 0);
                cr.paint();

                cr.rectangle(xshift, yshift, clip_width, clip_height);

                cr.clip();

                cr.set_source_surface(slide2, 0, 0);
                cr.paint();

                break;
            case Poppler.PageTransitionType.BLINDS:
                int nblinds = 10;

                // Add an extra pixel to be on the safe side due to rounding
                if (this.transition.alignment ==
                    Poppler.PageTransitionAlignment.VERTICAL) {
                    clip_width = progress*width/nblinds + 1;
                } else {
                    clip_height = progress*height/nblinds + 1;
                }

                cr.set_source_surface(prev, 0, 0);
                cr.paint();

                for (int i = 0; i < nblinds; i++) {
                    if (this.transition.alignment ==
                        Poppler.PageTransitionAlignment.VERTICAL) {
                        xshift = i*width/nblinds - clip_width/2;
                    } else {
                        yshift = i*height/nblinds - clip_height/2;
                    }
                    cr.rectangle(xshift, yshift, clip_width, clip_height);
                }
                cr.clip();

                cr.set_source_surface(next, 0, 0);
                cr.paint();

                break;
            default:
                cr.set_source_surface(next, 0, 0);
                cr.paint();

                break;
            }
        }
    }
}
