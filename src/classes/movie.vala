using Gst;

using pdfpc;

namespace pdfpc {
    
    public class Movie: GLib.Object {
        
        protected Pipeline pipeline;
        protected PresentationController controller;
        
        public Movie(string file, string? arguments, Poppler.Rectangle area,
                     PresentationController controller) {
            base();
            this.controller = controller;
            this.establish_pipeline(file, area);
            this.play();
        }
        
        protected void establish_pipeline(string file, Poppler.Rectangle area) {
            this.pipeline = new Pipeline("mypipeline");
            var src = ElementFactory.make("videotestsrc", "source");
            var tee = ElementFactory.make("tee", "tee");
            this.pipeline.add_many(src, tee);
            src.link(tee);
            
            Gdk.Rectangle rect;
            int n = 0;
            ulong xid;
            while (true) {
                xid = controller.video_pos(n, area, out rect);
                if (xid == 0)
                    break;
                var sink = ElementFactory.make("xvimagesink", @"sink$n");
                var queue = ElementFactory.make("queue", @"queue$n");
                this.pipeline.add_many(queue,sink);
                tee.link(queue);
                queue.link(sink);
                var xoverlay = sink as XOverlay;
                xoverlay.set_xwindow_id(xid);
                xoverlay.set_render_rectangle(rect.x, rect.y, rect.width, rect.height);
                n++;
            }
        }
        
        public void play() {
            this.pipeline.set_state(State.PLAYING);
        }
    }
}
