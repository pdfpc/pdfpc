using Gst;

using pdfpc;

namespace pdfpc {
    
    public class Movie: GLib.Object {
        
        protected dynamic Element pipeline;
        protected PresentationController controller;
        
        public Movie(string file, string? arguments, Poppler.Rectangle area,
                     PresentationController controller) {
            base();
            this.controller = controller;
            this.establish_pipeline(file, area);
            this.play();
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
            bus.add_watch(on_message);
        }
        
        public void play() {
            this.pipeline.set_state(State.PLAYING);
        }
        
        private bool on_message(Gst.Bus bus, Message message) {
            if (message.type == MessageType.ERROR) {
                GLib.Error err;
                string debug;
                message.parse_error(out err, out debug);
                stdout.printf("Error %s\n", err.message);
            }
            return true;
        }
    }
}
