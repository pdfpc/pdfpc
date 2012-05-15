using Gst;

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
        private Gee.HashMap<string, Movie> movies;
        
        public MovieManager(PresentationController controller) {
            base();
            this.controller = controller;
            this.movies = new Gee.HashMap<string, Movie>();
        }
        
        public bool click(string file, string? argument, uint page_number, Poppler.Rectangle area) {
            string key = @"$(area.x1):$(area.x2):$(area.y1):$(area.y2)";
            Movie? movie = movies.get(key);
            if (movie == null) {
                movie = new Movie(file, argument, area, this.controller);
                movies.set(key, movie);
            }
            movie.toggle_play();
            return true;
        }
    }
    
    public class Movie: GLib.Object {
        
        protected dynamic Element pipeline;
        protected PresentationController controller;
        protected bool eos;
        
        public Movie(string file, string? arguments, Poppler.Rectangle area,
                     PresentationController controller) {
            base();
            this.controller = controller;
            this.eos = false;
            this.establish_pipeline(file, area);
        }
        
        protected void establish_pipeline(string file, Poppler.Rectangle area) {
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
                queue.link(sink);
                var xoverlay = sink as XOverlay;
                xoverlay.set_xwindow_id(xid);
                xoverlay.set_render_rectangle(rect.x, rect.y, rect.width, rect.height);
                n++;
            }
            
            // This will likely have problems in Windows, where paths and urls have different separators.
            string uri;
            if (Path.is_absolute(file))
                uri = "file://" + file;
            else
                uri = Path.build_filename(Path.get_dirname(this.controller.get_pdf_url()), file);
            this.pipeline = ElementFactory.make("playbin2", "playbin");
            this.pipeline.uri = uri;
            this.pipeline.video_sink = bin;
            var bus = this.pipeline.get_bus();
            bus.add_signal_watch();
            bus.message["error"] += this.on_message;
            bus.message["eos"] += this.on_eos;
        }
        
        public void play() {
            if (this.eos) {
                this.eos = false;
                this.pipeline.seek_simple(Format.TIME, SeekFlags.FLUSH, 0);
            }
            this.pipeline.set_state(State.PLAYING);
        }
        
        public void toggle_play() {
            State state;
            ClockTime time = util_get_timestamp();
            this.pipeline.get_state(out state, null, time);
            if (state == State.PLAYING)
                this.pipeline.set_state(State.PAUSED);
            else
                this.play();
        }
        
        private void on_message(Gst.Bus bus, Message message) {
            GLib.Error err;
            string debug;
            message.parse_error(out err, out debug);
            stdout.printf("Error %s\n", err.message);
        }
        
        private void on_eos(Gst.Bus bus, Message message) {
            stdout.printf("EOS\n");
            // Can't seek to beginning w/o updating output, so mark to seek later
            this.eos = true;
            this.pipeline.set_state(State.PAUSED);
        }
    }
}
