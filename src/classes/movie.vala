using Gst;
using Cairo;

using pdfpc;

namespace pdfpc {
    
    public class MovieManager: GLib.Object {
        /**
         * The movie manager should be informed of any clicks on movies. It will
         * create, start, and stop them as appropriate.  It will also watch for
         * page changes and stop movies as appropriate.  There is no guarantee
         * that movie objects will persist past page changes.
         */
        
        protected PresentationController controller;
        protected Gee.HashMap<string, Movie> movies;
        protected bool connected = false;
        
        public MovieManager(PresentationController controller) {
            base();
            this.controller = controller;
            this.movies = new Gee.HashMap<string, Movie>();
        }
        
        public bool click(string file, string? argument, uint page_number, Poppler.Rectangle area) {
            if (!this.connected) {
                stdout.printf("Not connected\n");
                // Hook up notifications.  We have to wait until the views are created.
                var view = this.controller.main_view;
                if (view != null){
                    stdout.printf("Connecting\n");
                    view.leaving_slide.connect(this.on_leaving_slide);
                    this.connected = true;
                }
            }
            string key = @"$(area.x1):$(area.x2):$(area.y1):$(area.y2)";
            Movie? movie = movies.get(key);
            if (movie == null) {
                movie = new ControlledMovie(file, argument, area, this.controller);
                movies.set(key, movie);
                movie.play();
            } else
                movie.on_button_press();
            return true;
        }
        
        public void on_leaving_slide( View.Base source, int from, int to ) {
            foreach (var movie in this.movies.values)
                movie.stop();
            this.movies.clear(); // Is this enough to trigger garbage collection?
        }
    }
    
    public class Movie: GLib.Object {
        
        public dynamic Element pipeline;
        protected bool eos = false;
        
        public Movie(string file, string? arguments, Poppler.Rectangle area,
                     PresentationController controller) {
            base();
            this.establish_pipeline(file, area, controller);
        }
        
        protected void establish_pipeline(string file, Poppler.Rectangle area,
                                          PresentationController controller) {
            var bin = new Bin("bin");
            var tee = ElementFactory.make("tee", "tee");
            bin.add_many(tee);
            bin.add_pad(new GhostPad("sink", tee.get_pad("sink")));
            Gdk.Rectangle rect;
            int n = 0;
            ulong xid;
            while (true) {
                xid = controller.video_pos(n, area, out rect);
                if (xid == 0)
                    break;
                var sink = ElementFactory.make("xvimagesink", @"sink$n");
                var queue = ElementFactory.make("queue", @"queue$n");
                bin.add_many(queue,sink);
                tee.link(queue);
                var ad_element = this.link_additional(n, queue, bin, rect);
                ad_element.link(sink);
                
                var xoverlay = sink as XOverlay;
                xoverlay.set_xwindow_id(xid);
                xoverlay.set_render_rectangle(rect.x, rect.y, rect.width, rect.height);
                n++;
            }
            
            // This will likely have problems in Windows, where paths and urls have different separators.
            string uri;
            if (GLib.Path.is_absolute(file))
                uri = "file://" + file;
            else
                uri = GLib.Path.build_filename(GLib.Path.get_dirname(controller.get_pdf_url()), file);
            this.pipeline = ElementFactory.make("playbin2", "playbin");
            this.pipeline.uri = uri;
            this.pipeline.video_sink = bin;
            var bus = this.pipeline.get_bus();
            bus.add_signal_watch();
            bus.message["error"] += this.on_message;
            bus.message["eos"] += this.on_eos;
        }
        
        protected virtual Element link_additional(int n, Element source, Bin bin,
                                                  Gdk.Rectangle rect) {
            return source;
        }
        
        public virtual void play() {
            if (this.eos) {
                this.eos = false;
                this.pipeline.seek_simple(Gst.Format.TIME, SeekFlags.FLUSH, 0);
            }
            this.pipeline.set_state(State.PLAYING);
        }
        
        public virtual void pause() {
            this.pipeline.set_state(State.PAUSED);
        }
        
        public virtual void stop() {
            this.pipeline.set_state(State.NULL);
        }
        
        public virtual void toggle_play() {
            State state;
            ClockTime time = util_get_timestamp();
            this.pipeline.get_state(out state, null, time);
            if (state == State.PLAYING)
                this.pause();
            else
                this.play();
        }
        
        public virtual void on_message(Gst.Bus bus, Message message) {
            GLib.Error err;
            string debug;
            message.parse_error(out err, out debug);
            stdout.printf("Error %s\n", err.message);
        }
        
        public virtual void on_eos(Gst.Bus bus, Message message) {
            stdout.printf("EOS\n");
            // Can't seek to beginning w/o updating output, so mark to seek later
            this.eos = true;
            this.pause();
        }
        
        public virtual void on_button_press() {
            this.toggle_play();
        }
    }
    
    
    public class ControlledMovie: Movie {
        
        protected Gdk.Rectangle rect;
        protected double scalex;
        protected double scaley;
        protected int vheight;
        protected int64 duration;
        protected double seek_bar_height = 20;
        protected double seek_bar_padding = 2;
        protected bool in_seek_bar = false;
        protected uint refresh_timeout = 0;
        protected bool mouse_drag = false;
        protected bool drag_was_playing;
        
        public ControlledMovie(string file, string? arguments, Poppler.Rectangle area,
                     PresentationController controller) {
            base(file, arguments, area, controller);
            controller.main_view.motion_notify_event.connect(this.on_motion);
            //view.button_press_event.connect(this.on_button_press); Trapped by SignalProvider...
            controller.main_view.button_release_event.connect(this.on_button_release);
        }
        
        protected override Element link_additional(int n, Element source, Bin bin,
                                                   Gdk.Rectangle rect) {
            if (n != 0)
                return source;
            
            this.rect = rect;
            
            var scale = ElementFactory.make("videoscale", "scale");
            var rate = ElementFactory.make("videorate", "rate");
            var adaptor1 = ElementFactory.make("ffmpegcolorspace", "adaptor1");
            var adaptor2 = ElementFactory.make("ffmpegcolorspace", "adaptor2");
            dynamic Element overlay = ElementFactory.make("cairooverlay", "overlay");
            var caps = Caps.from_string(
                "video/x-raw-rgb," + // Same as cairooverlay; hope to minimize transformations
                "framerate=[25/1,2147483647/1]," + // At least 25 fps
                @"width=$(rect.width),height=$(rect.height)"
            );
            dynamic Element filter = ElementFactory.make("capsfilter", "filter");
            filter.caps = caps;
            bin.add_many(adaptor1, adaptor2, overlay, scale, rate, filter);
            if (!source.link_many(rate, scale, adaptor1, filter, overlay, adaptor2))
                stdout.printf("Trouble in linksville\n");
            
            overlay.draw.connect(this.on_draw);
            overlay.caps_changed.connect(this.on_prepare);
            
            return adaptor2;
        }
        
        public void on_prepare(Element overlay, Caps caps){
            int width = -1, height = -1;
            VideoFormat format = VideoFormat.UNKNOWN;
            Gst.video_format_parse_caps(caps, ref format, ref width, ref height);
            stdout.printf("%ix%i\n", width, height);
            scalex = 1.0*width / rect.width;
            scaley = 1.0*height / rect.height;
            vheight = height;
            
            var tformat = Gst.Format.TIME;
            overlay.query_duration(ref tformat, out duration);
            stdout.printf("%f s\n", 1.0*duration / SECOND);
        }
        
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
        
        private void set_mouse_in(double mx, double my, out double x, out double y) {
            x = mx - rect.x;
            y = rect.y + rect.height - my;
            this.in_seek_bar = (x > 0 && x < rect.width && y > 0 && y < seek_bar_height);
        }
        
        public int64 mouse_seek(double x, double y) {
            double seek_fraction = (x - this.seek_bar_padding) / (rect.width - 2*this.seek_bar_padding);
            if (seek_fraction < 0) seek_fraction = 0;
            if (seek_fraction > 1) seek_fraction = 1;
            var seek_time = (int64)(seek_fraction * this.duration);
            this.pipeline.seek_simple(Gst.Format.TIME, SeekFlags.FLUSH, seek_time);
            return seek_time;
        }
        
        public bool on_motion(Gdk.EventMotion event) {
            double x, y;
            this.set_mouse_in(event.x, event.y, out x, out y);
            if (this.mouse_drag)
                this.mouse_seek(x, y);
            return false;
        }
        
        public override void on_button_press() {
            // This event is acutally grabbed elsewhere, so we don't get the details.  Instead,
            // decide what to do based on the last-reported mouse location.
            if (!this.in_seek_bar)
                this.toggle_play();
            else {
                this.mouse_drag = true;
                this.drag_was_playing = (this.pipeline.current_state == State.PLAYING);
                this.pause();
                this.stop_refresh();
            }
        }
        
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
        
        public void start_refresh() {
            if (this.refresh_timeout != 0)
                return;
            int64 curr_time;
            var tformat = Gst.Format.TIME;
            this.pipeline.query_position(ref tformat, out curr_time);
            this.start_refresh_time(curr_time);
        }
        
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
        
        public void stop_refresh() {
            if (this.refresh_timeout == 0)
                return;
            Source.remove(this.refresh_timeout);
            this.refresh_timeout = 0;
        }

        public override void play() {
            this.stop_refresh();
            base.play();
        }
        
        public override void pause() {
            base.pause();
            this.start_refresh();
        }

    }
}
