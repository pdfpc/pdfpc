/**
 * Action mapping for movies.
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2012 Robert Schroll <rschroll@gmail.com>
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

using Gst;
using Cairo;

using pdfpc;

namespace pdfpc {
    /**
     * An error in constructing a gstreamer pipeline.
     */
    public errordomain PipelineError {
        ElementConstruction,
        Linking
    }
    /**
     * Make a non-NULL gstreamer element, or raise an error.
     */
    public Element gst_element_make(string factoryname, string? name) throws PipelineError {
        var element = ElementFactory.make(factoryname, name);
        if (element == null)
            throw new PipelineError.ElementConstruction(@"Could not make element $name of type $factoryname.");
        return element;
    }
    
    /**
     * A movie with basic controls -- click to start and stop.
     */
    public class Movie: ActionMapping {
        /**
         * The gstreamer pipeline for playback.
         */
        public dynamic Element pipeline;
        
        /**
         * A flag to indicate when we've reached the End Of Stream, so we
         * know whether to restart on the next click.
         */
        protected bool eos = false;
        
        /**
         * A flag to indicated whether the movie should be played in a loop.
         */
        protected bool loop;
        
        /**
         * If the movie was attached to the PDF file, we store it in a temporary
         * file, whose name we store here.  If not, this will be the blank string.
         */
        protected string temp;
        
        /**
         * Base constructor does nothing.
         */
        public Movie() {
            base();
        }
        
        /**
         * This initializer is odd -- it's called from an other object from the
         * one your are initializing.  This is so subclasses can override this
         * to do custom initialization without having to implement the new_from_...
         * methods.  This can't be a good way to handle this, but I've yet to figure
         * out a better one.
         */
        public virtual void init_other(ActionMapping other, Poppler.Rectangle area,
                PresentationController controller, Poppler.Document document,
                string uri, bool autostart, bool loop, bool temp=false) {
            other.init(area, controller, document);
            var movie = other as Movie;
            movie.loop = loop;
            movie.temp = temp ? uri.substring(7) : "";
            GLib.Idle.add( () => {
                movie.establish_pipeline(uri);
                if (autostart)
                    movie.play();
                return false;
            } );
        }
        
        /**
         * Create a new Movie from a link mapping, if the link of type "LAUNCH"
         * and points to a file that looks like a video file.  The video is
         * played back in the area of the hyperlink, which is probably not
         * conforming to the PDF spec, but it makes this an easy way to include
         * movies in presentations.  As a bonus, a query string on the video
         * filename can activate the autostart and loop properties.  (E.g., link
         * to movie.avi?autostart&loop to make movie.avi start playing with the
         * page is entered and loop back to the beginning when it reaches the end.)
         * 
         * In LaTeX, create such links with
         *      \usepackage{hyperref}
         *      \href{run:<movie file>}{<placeholder content>}
         * Since the video will take the shape of the placeholder content, you
         * probably want to use a frame from the movie to get the right aspect
         * ratio.
         */
        public override ActionMapping? new_from_link_mapping(Poppler.LinkMapping mapping,
                PresentationController controller, Poppler.Document document) {
            if (mapping.action.type != Poppler.ActionType.LAUNCH)
                return null;
            
            var file = ((Poppler.ActionLaunch*)mapping.action).file_name;
            var splitfile = file.split("?", 2);
            file = splitfile[0];
            var querystring = "";
            if (splitfile.length == 2)
                querystring = splitfile[1];
            var queryarray = querystring.split("&");
            var autostart = "autostart" in queryarray;
            var loop = "loop" in queryarray;
            
            string uri = filename_to_uri(file, controller.get_pdf_url());
            bool uncertain;
            var ctype = GLib.ContentType.guess(uri, null, out uncertain);
            if (!("video" in ctype))
                return null;
            
            var type = Type.from_instance(this);
            var new_obj = GLib.Object.new(type) as ActionMapping;
            this.init_other(new_obj, mapping.area, controller, document, uri, autostart, loop);
            return new_obj;
        }
        
        /**
         * Create a new Movie from an annotation mapping, if the annotation is a
         * screen annotation with a video file or a movie annotation.  Various
         * options to modify the behavior of the playback are not yet supported,
         * since they're missing from poppler.
         * 
         * In LaTeX, create screen annotations with
         *      \usepackage{movie15}
         *      \includemovie[text=<placeholder content>]{}{}{<movie file>}
         * The movie size is determined by the size of the placeholder content, so
         * a frame from the movie is a good choice.  Note that the poster, autoplay,
         * and repeat options are not yet supported.  (Also note that movie15 is
         * deprecated, but it works as long as you run ps2pdf with the -dNOSAFER flag.)
         * 
         * In LaTeX, create movie annotations with
         *      \usepackage{multimedia}
         *      \movie[<options>]{<placeholder content>}{<movie file>}
         * The movie size is determined from the size of the placeholder content or
         * the width and height options.  Note that the autostart, loop/repeat, and
         * poster options are not yet supported.
         */
        public override ActionMapping? new_from_annot_mapping(Poppler.AnnotMapping mapping,
                PresentationController controller, Poppler.Document document) {
            var annot = mapping.annot;
            string uri;
            bool temp = false;
            switch (annot.get_annot_type()) {
            case Poppler.AnnotType.SCREEN:
                if (!("video" in annot.get_contents()))
                    return null;
                
                var action = ((Poppler.AnnotScreen) annot).get_action();
                var movie = (Poppler.Media) action.movie.movie;
                
                if (movie.is_embedded()) {
                    string tmp_fn;
                    int fh;
                    try {
                        fh = FileUtils.open_tmp(null, out tmp_fn);
                    } catch (FileError e) {
                        warning("Could not create temp file: %s", e.message);
                        return null;
                    }
                    FileUtils.close(fh);
                    try {
                        movie.save(tmp_fn);
                    } catch (Error e) {
                        warning("Could not save temp file: %s", e.message);
                        return null;
                    }
                    uri = "file://" + tmp_fn;
                    temp = true;
                } else {
                    string file = movie.get_filename();
                    if (file == null) {
                        warning("Movie not embedded and has no file name");
                        return null;
                    }
                    uri = filename_to_uri(file, controller.get_pdf_url());
                    temp = false;
                }
                break;
            case Poppler.AnnotType.MOVIE:
                var movie = ((Poppler.AnnotMovie) annot).get_movie();
                if (movie.need_poster())
                    warning("Movie requests poster.  Not yet supported.");
                string file = movie.get_filename();
                if (file == null) {
                    warning("Movie has no file name");
                    return null;
                }
                uri = filename_to_uri(file, controller.get_pdf_url());
                temp = false;
                break;
            default:
                return null;
            }
            
            var type = Type.from_instance(this);
            var new_obj = GLib.Object.new(type) as ActionMapping;
            this.init_other(new_obj, mapping.area, controller, document, uri, false, false, temp);
            return new_obj;
        }
        
        /**
         * Set up the gstreamer pipeline.
         */
        protected void establish_pipeline(string uri) {
            var bin = new Bin("bin");
            var tee = ElementFactory.make("tee", "tee");
            bin.add_many(tee);
            bin.add_pad(new GhostPad("sink", tee.get_pad("sink")));
            Gdk.Rectangle rect;
            int n = 0;
            uint xid;
            while (true) {
                xid = this.controller.overlay_pos(n, this.area, out rect);
                if (xid == 0)
                    break;
                var sink = ElementFactory.make("xvimagesink", @"sink$n");
                var queue = ElementFactory.make("queue", @"queue$n");
                bin.add_many(queue,sink);
                tee.link(queue);
                var ad_element = this.link_additional(n, queue, bin, rect);
                ad_element.link(sink);
                
                var xoverlay = sink as XOverlay;
                xoverlay.set_window_handle(xid);
                xoverlay.handle_events(false);
                xoverlay.set_render_rectangle(rect.x, rect.y, rect.width, rect.height);
                n++;
            }
            
            this.pipeline = ElementFactory.make("playbin2", "playbin");
            this.pipeline.uri = uri;
            this.pipeline.video_sink = bin;
            var bus = this.pipeline.get_bus();
            bus.add_signal_watch();
            bus.message["error"] += this.on_message;
            bus.message["eos"] += this.on_eos;
        }
        
        /**
         * Provides a place for subclasses to hook additional elements into
         * the pipeline.  n is which output we're dealing with; 0 is where
         * specialized controls should appear.  Additional elements should
         * be added to bin and linked from source.  The last element linked
         * should be returned, so that the tail end of the pipeline can be
         * attached.
         * 
         * This stub does nothing.
         */
        protected virtual Element link_additional(int n, Element source, Bin bin,
                                                  Gdk.Rectangle rect) {
            return source;
        }
        
        /**
         * Utility function for converting filenames to uris.
         */
        public string filename_to_uri(string file, string pdf_url) {
            var uriRE = new Regex("^[a-z]*://");
            if (uriRE.match(file))
                return file;
            if (GLib.Path.is_absolute(file))
                return "file://" + file;
            var dirname = GLib.Path.get_dirname(pdf_url);
            return GLib.Path.build_filename(dirname, file);
        }
        
        /**
         * Play the movie, rewinding to the beginning if we had reached the
         * end.
         */
        public virtual void play() {
            if (this.eos) {
                this.eos = false;
                this.pipeline.seek_simple(Gst.Format.TIME, SeekFlags.FLUSH, 0);
            }
            this.pipeline.set_state(State.PLAYING);
        }
        
        /**
         * Pause playback.
         */
        public virtual void pause() {
            this.pipeline.set_state(State.PAUSED);
        }
        
        /**
         * Stop playback.
         */
        public virtual void stop() {
            this.pipeline.set_state(State.NULL);
        }
        
        /**
         * Pause if playing, as vice versa.
         */
        public virtual void toggle_play() {
            State state;
            ClockTime time = util_get_timestamp();
            this.pipeline.get_state(out state, null, time);
            if (state == State.PLAYING)
                this.pause();
            else
                this.play();
        }
        
        /**
         * Basic printout of error messages on the pipeline.
         */
        public virtual void on_message(Gst.Bus bus, Message message) {
            GLib.Error err;
            string debug;
            message.parse_error(out err, out debug);
            stderr.printf("Gstreamer error %s\n", err.message);
        }
        
        /**
         * Mark reaching the end of stream, and set state to paused.
         */
        public virtual void on_eos(Gst.Bus bus, Message message) {
            if (this.loop) {
                this.pipeline.seek_simple(Gst.Format.TIME, SeekFlags.FLUSH, 0);
            } else {
                // Can't seek to beginning w/o updating output, so mark to seek later
                this.eos = true;
                this.pause();
            }
        }
        
        /**
         * Play and pause on mouse clicks.
         */
        public override bool on_button_press(Gtk.Widget widget, Gdk.EventButton event) {
            this.toggle_play();
            return true;
        }
        
        /**
         * When we leave the page, stop the movie and delete any temporary files.
         */
        public override void deactivate() {
            this.stop();
            if (this.temp != "")
                if (FileUtils.unlink(this.temp) != 0)
                    warning("Problem deleting temp file %s", this.temp);
        }
    }
    
    /**
     * A Movie with overlaid controls; specifically a draggable progress bar.
     */
    public class ControlledMovie: Movie {
        /**
         * The screen rectangle associated with the movie.
         */
        protected Gdk.Rectangle rect;
        
        /**
         * Data on how the movie playback must fit on the page.
         */
        protected double scalex;
        protected double scaley;
        protected int vheight;
        
        /**
         * The length of the movie, in nanoseconds (!).
         */
        protected int64 duration;
        
        /**
         * Settings for the appearance of the progress bar.
         */
        protected double seek_bar_height = 20;
        protected double seek_bar_padding = 2;
        
        /**
         * A timeout signal is used to update the GUI when the movie is paused,
         * since we won't get new frames.
         */
        protected uint refresh_timeout = 0;
        
        /**
         * Flags about the current state of mouse interaction.
         */
        protected bool in_seek_bar = false;
        protected bool mouse_drag = false;
        protected bool drag_was_playing;
        
        /**
         * Basic constructor does nothing.
         */
        public ControlledMovie() {
            base();
        }
        
        /**
         * The initialization unique to this class.  See the documentation for
         * Movie.init_other that attempts to justify this ugliness.
         */
        public override void init_other(ActionMapping other, Poppler.Rectangle area,
                PresentationController controller, Poppler.Document document, string file, bool autostart, bool loop, bool temp=false) {
            base.init_other(other, area, controller, document, file, autostart, loop, temp);
            var movie = other as ControlledMovie;
            controller.main_view.motion_notify_event.connect(movie.on_motion);
            controller.main_view.button_release_event.connect(movie.on_button_release);
        }
        
        /**
         * Hook up the elements to draw the controls to the first output leg.
         */
        protected override Element link_additional(int n, Element source, Bin bin,
                                                   Gdk.Rectangle rect) {
            if (n != 0)
                return source;
            
            this.rect = rect;
            
            dynamic Element overlay;
            Element adaptor2;
            try {
                var scale = gst_element_make("videoscale", "scale");
                var rate = gst_element_make("videorate", "rate");
                var adaptor1 = gst_element_make("ffmpegcolorspace", "adaptor1");
                adaptor2 = gst_element_make("ffmpegcolorspace", "adaptor2");
                overlay = gst_element_make("cairooverlay", "overlay");
                var caps = Caps.from_string(
                    "video/x-raw-rgb," + // Same as cairooverlay; hope to minimize transformations
                    "framerate=[25/1,2147483647/1]," + // At least 25 fps
                    @"width=$(rect.width),height=$(rect.height)"
                );
                dynamic Element filter = gst_element_make("capsfilter", "filter");
                filter.caps = caps;
                bin.add_many(adaptor1, adaptor2, overlay, scale, rate, filter);
                if (!source.link_many(rate, scale, adaptor1, filter, overlay, adaptor2))
                    throw new PipelineError.Linking("Could not link pipeline.");
            } catch (PipelineError err) {
                warning(@"Error creating control pipeline: $(err.message)");
                return source;
            }
            
            overlay.draw.connect(this.on_draw);
            overlay.caps_changed.connect(this.on_prepare);
            
            return adaptor2;
        }
        
        /**
         * When we find out the properties of the movie, we can work out how it
         * needs to be scaled to fit in the alloted area.  (This is only important
         * for the view with the controls.)
         */
        public void on_prepare(Element overlay, Caps caps){
            int width = -1, height = -1;
            VideoFormat format = VideoFormat.UNKNOWN;
            Gst.video_format_parse_caps(caps, ref format, ref width, ref height);
            scalex = 1.0*width / rect.width;
            scaley = 1.0*height / rect.height;
            vheight = height;
            
            var tformat = Gst.Format.TIME;
            overlay.query_duration(ref tformat, out duration);
        }
        
        /**
         * Everytime we get a new frame, update the progress bar.
         */
        public void on_draw(Element overlay, Context cr, uint64 timestamp, uint64 duration) {
            // Transform to work from bottom left, in screen coordinates
            cr.translate(0, this.vheight);
            cr.scale(this.scalex, -this.scaley);
            
            this.draw_seek_bar(cr, timestamp);
        }
        
        private void draw_seek_bar(Context cr, uint64 timestamp) {
            double fraction = 1.0*timestamp / this.duration;
            if (this.in_seek_bar || this.mouse_drag) {
                var bar_end = fraction * (rect.width - 2*this.seek_bar_padding);
                cr.rectangle(0, 0, rect.width, this.seek_bar_height);
                cr.set_source_rgba(0,0,0,0.8);
                cr.fill();
                cr.rectangle(this.seek_bar_padding, this.seek_bar_padding,
                            bar_end, this.seek_bar_height-4);
                cr.set_source_rgba(1,1,1,0.8);
                cr.fill();
                
                var time_in_sec = (int)(timestamp / SECOND);
                var timestring = "%i:%02i".printf(time_in_sec/60, time_in_sec%60);
                var dur_in_sec = (int)(this.duration / SECOND);
                var durstring = "%i:%02i".printf(dur_in_sec/60, dur_in_sec%60);
                TextExtents te;
                FontOptions fo = new FontOptions();
                fo.set_antialias(Antialias.GRAY);
                cr.set_font_options(fo);
                cr.select_font_face("sans", FontSlant.NORMAL, FontWeight.NORMAL);
                cr.set_font_size(this.seek_bar_height - 2*seek_bar_padding);
                
                cr.text_extents(durstring, out te);
                if ((bar_end + te.width + 4*this.seek_bar_padding) < rect.width) {
                    cr.move_to(rect.width - te.width - 2*this.seek_bar_padding,
                               this.seek_bar_height/2 - te.height/2);
                    cr.set_source_rgba(0.8,0.8,0.8,1);
                    cr.save();
                    cr.scale(1, -1);
                    cr.show_text(durstring);
                    cr.restore();
                }
                
                cr.text_extents(timestring, out te);
                if (bar_end > te.width) {
                    cr.move_to(bar_end - te.width, this.seek_bar_height/2 - te.height/2);
                    cr.set_source_rgba(0,0,0,1);
                } else {
                    cr.move_to(bar_end + 2*this.seek_bar_padding, this.seek_bar_height/2 - te.height/2);
                    cr.set_source_rgba(0.8,0.8,0.8,1);
                }
                cr.save();
                cr.scale(1,-1);
                cr.show_text(timestring);
                cr.restore();
                
            } else {
                cr.rectangle(0, 0, rect.width, 4);
                cr.set_source_rgba(0,0,0,0.8);
                cr.fill();
                cr.rectangle(1, 1, fraction * (rect.width - 2), 2);
                cr.set_source_rgba(1,1,1,0.8);
                cr.fill();
            }
        }
        
        /**
         * Set a flag about whether the mouse is currently in the progress bar.
         */
        private void set_mouse_in(double mx, double my, out double x, out double y) {
            x = mx - rect.x;
            y = rect.y + rect.height - my;
            this.in_seek_bar = (x > 0 && x < rect.width && y > 0 && y < seek_bar_height);
        }
        
        /**
         * Seek to the time indicated by the mouse's position on the progress bar.
         */
        public int64 mouse_seek(double x, double y) {
            double seek_fraction = (x - this.seek_bar_padding) / (rect.width - 2*this.seek_bar_padding);
            if (seek_fraction < 0) seek_fraction = 0;
            if (seek_fraction > 1) seek_fraction = 1;
            var seek_time = (int64)(seek_fraction * this.duration);
            this.pipeline.seek_simple(Gst.Format.TIME, SeekFlags.FLUSH, seek_time);
            return seek_time;
        }
        
        /**
         * Seek if we're dragging the progress bar.
         */
        public bool on_motion(Gdk.EventMotion event) {
            double x, y;
            this.set_mouse_in(event.x, event.y, out x, out y);
            if (this.mouse_drag)
                this.mouse_seek(x, y);
            return false;
        }
        
        /**
         * If we click outside of the progress bar, toggle the playing state.
         * Inside the progress bar, pause or stop the timeout, and start the
         * drag state.
         */
        public override bool on_button_press(Gtk.Widget widget, Gdk.EventButton event) {
            State state;
            ClockTime time = util_get_timestamp();
            this.pipeline.get_state(out state, null, time);
            if (state == State.NULL || widget != this.controller.main_view) {
                this.toggle_play();
                return true;
            }
            
            double x, y;
            this.set_mouse_in(event.x, event.y, out x, out y);
            if (!this.in_seek_bar)
                this.toggle_play();
            else {
                this.mouse_drag = true;
                this.drag_was_playing = (this.pipeline.current_state == State.PLAYING);
                this.pause();
                this.mouse_seek(x, y);
                this.stop_refresh();
            }
            return true;
        }
        
        /**
         * Stop the drag state and restart either playback or the timeout,
         * depending on the previous state.
         */
        public bool on_button_release(Gdk.EventButton event) {
            double x, y;
            this.set_mouse_in(event.x, event.y, out x, out y);
            if (this.mouse_drag) {
                var seek_time = this.mouse_seek(x, y);
                if (this.drag_was_playing || this.eos) {
                    this.eos = false;
                    this.play();
                } else
                    // Otherwise, time resets to 0 (don't know why).
                    this.start_refresh_time(seek_time);
            }
            this.mouse_drag = false;
            return false;
        }
        
        /**
         * Start a timeout event to refresh the GUI every 50ms.  To be used when
         * the movie is paused, so that the controls can still be updated.
         */
        public void start_refresh() {
            if (this.refresh_timeout != 0)
                return;
            int64 curr_time;
            var tformat = Gst.Format.TIME;
            this.pipeline.query_position(ref tformat, out curr_time);
            this.start_refresh_time(curr_time);
        }
        
        /**
         * In the timeout, we seek to the current time, which is enough to force
         * gstreamer to redraw the current frame.
         */
        public void start_refresh_time(int64 curr_time) {
            if (this.eos)
                // Seeking to the very end won't refresh the output.
                curr_time -= 1;
            if (this.refresh_timeout != 0)
                Source.remove(this.refresh_timeout);
            this.refresh_timeout = Timeout.add(50, () => {
                this.pipeline.seek_simple(Gst.Format.TIME, SeekFlags.FLUSH, curr_time);
                return true;
            } );
        }
        
        /**
         * Stop the refresh timeout.
         */
        public void stop_refresh() {
            if (this.refresh_timeout == 0)
                return;
            Source.remove(this.refresh_timeout);
            this.refresh_timeout = 0;
        }
        
        /**
         * Stop the refresh timeout when we start playing.
         */
        public override void play() {
            this.stop_refresh();
            base.play();
        }
        
        /**
         * Start the refresh timeout when we pause.
         */
        public override void pause() {
            base.pause();
            this.start_refresh();
        }
    }
}
