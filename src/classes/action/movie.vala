/**
 * Action mapping for movies.
 *
 * This file is part of pdfpc.
 *
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2014-2015 Séverin Lemaignan
 * Copyright 2015,2017 Andreas Bilke
 * Copyright 2016 Andy Barry
 * Copyright 2017 Philipp Berndt
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
     * An error in constructing a gstreamer pipeline.
     */
    public errordomain PipelineError {
        ElementConstruction,
        Linking
    }

    /**
     * Datatype to hold video configuration (like size, pos, parent window)
     */
    public class VideoConf : Object {
        public int display_num { get; set; }
        public Gdk.Rectangle rect { get; set; }
        public Window.ControllableWindow window { get; set; }
    }

    protected struct PlaybackOptions {
        /**
         * A flag to indicate whether the movie should start automatically.
         */
        bool autostart;

        /**
         * A flag to indicate whether the movie should be played in a loop.
         */
        bool loop;

        /**
         * A flag to indicate whether the progress bar should be supressed.
         */
        bool noprogress;

         /**
         * A flag to indicate whether the audio should be played or not.
         */
        bool noaudio;

        /**
         * Show the first frame of the movie before playing.
         */
        bool poster;

        /**
         * Time, in second from the start of the movie, at which the playback
         * should start and stop (stop = 0 means 'to the end').
         */
        int starttime;
        int stoptime;
    }

    /**
     * Make a non-NULL gstreamer element, or raise an error.
     */
    public Gst.Element gst_element_make(string factoryname, string name) throws PipelineError {
        var element = Gst.ElementFactory.make(factoryname, name);
        if (element == null) {
            throw new PipelineError.ElementConstruction(
                @"Could not make element $name of type $factoryname.");
        }
        return element;
    }

    /**
     * A Movie with overlaid controls; specifically a draggable progress bar.
     */
    public class ControlledMovie: ActionMapping {
        /**
         * The gstreamer pipeline for playback.
         */
        protected Gst.Element pipeline;

        /**
         * Stores the gtk sink widgets for later removal from
         * the layout
         */
        protected Gee.List<Gtk.Widget> sinks;

        /**
         * A flag indicating that the video widget(s) are shown
         */
        protected bool shown = false;

        public string filename {
            get; protected set;
        }

        /**
         * Cursors for various video states/subwidgets
         */
        protected Gdk.Cursor pause_cursor;
        protected Gdk.Cursor play_cursor;
        protected Gdk.Cursor drag_cursor;

        /**
         * A flag to indicate when we've reached the End Of Stream, so we
         * know whether to restart on the next click.
         */
        protected bool eos = false;

        /**
         * If the movie was attached to the PDF file, we store it in a temporary
         * file, whose name we store here.  If not, this will be the blank string.
         */
        protected string temp;
        /**
         * The presenter screen rectangle associated with the movie.
         */
        protected Gdk.Rectangle rect;

        /**
         * The movie dimensions (pixels).
         */
        protected int video_w;
        protected int video_h;

        /**
         * Data on how the movie playback must fit on the page.
         */
        protected double scalex;
        protected double scaley;

        /**
         * The length of the movie, in nanoseconds (!).
         */
        protected int64 duration;

        /**
         * The desired font size (in *video* pixels!)
         */
        protected double seek_bar_fontsize = 16;

        /**
         * Settings for the appearance of the progress bar (in screen pixels).
         */
        protected double seek_bar_height;
        protected double seek_bar_padding = 2;

        /**
         * Flags about the current state of mouse interaction.
         */
        protected bool in_seek_bar = false;
        protected bool mouse_drag = false;
        protected bool drag_was_playing;

        /**
         * The position where we switched to pause mode
         */
        protected int64 paused_at = 0;

        protected PlaybackOptions options;

        construct {
            this.type = ActionType.MOVIE;

            this.sinks = new Gee.ArrayList<Gtk.Widget>();

            var display = Gdk.Display.get_default();
            this.pause_cursor = this.load_cursor(display, "pause_cur.svg");
            this.play_cursor  = this.load_cursor(display, "play_cur.svg");
            this.drag_cursor  = new Gdk.Cursor.from_name(display, "hand1");
        }

        ~ControlledMovie() {
            if (this.pipeline != null) {
                this.pipeline.set_state(Gst.State.NULL);
            }
        }

        /**
         * Auxiliary part of init_movie() that can be called asynchronously
         * via GLib.Idle.add()
         */
        protected void init_movie2(ControlledMovie movie,
                string uri, string? suburi) {
            movie.establish_pipeline(uri, suburi);
            if (movie.pipeline == null) {
                return;
            }

            movie.pipeline.set_state(Gst.State.PAUSED);
            // wait until the pipeline is actually in PAUSED mode
            movie.pipeline.get_state(null, null, Gst.CLOCK_TIME_NONE);

            // initial seek to set the starting point
            movie.pipeline.seek_simple(Gst.Format.TIME, Gst.SeekFlags.FLUSH,
                movie.options.starttime*Gst.SECOND);

            if (movie.options.autostart) {
                movie.play();
            } else if (!movie.options.poster) {
                movie.hide();
            }
        }

        /**
         * Inits  the movie
         */
        protected void init_movie(ControlledMovie movie, Poppler.Rectangle area,
                PresentationController controller,
                string uri, string? suburi, PlaybackOptions options,
                bool temp = false) {
            movie.init(area, controller);

            movie.options = options;

            movie.temp = temp ? uri.substring(7) : "";

#if MOVIE_LOAD_ASYNC
            GLib.Idle.add( () => {
                this.init_movie2(movie, uri, suburi);
                return false;
            } );
#else
            this.init_movie2(movie, uri, suburi);
#endif
        }

        /**
         * Create a new Movie from a link mapping, if the link of type "LAUNCH"
         * and points to a file that looks like a video file.  The video is
         * played back in the area of the hyperlink, which is probably not
         * conforming to the PDF spec, but it makes this an easy way to include
         * movies in presentations.  As a bonus, a query string on the video
         * filename can activate the autostart and loop properties.  (E.g., link
         * to movie.avi?autostart&loop to make movie.avi start playing with the
         * page is entered and loop back to the beginning when it reaches the
         * end.)
         */
        protected override ActionMapping? new_from_link_mapping(Poppler.LinkMapping mapping,
                PresentationController controller) {
            if (mapping.action.type != Poppler.ActionType.LAUNCH) {
                return null;
            }

            string file = ((Poppler.ActionLaunch*) mapping.action).file_name;
            string[] splitfile = file.split("?", 2);
            file = splitfile[0];
            string querystring = "";
            if (splitfile.length == 2) {
                querystring = splitfile[1];
            }
            string[] queryarray = querystring.split("&");

            options.autostart = "autostart" in queryarray;
            options.loop = "loop" in queryarray;
            options.noprogress = "noprogress" in queryarray;
            options.noaudio = "noaudio" in queryarray;
            options.poster = false;
            options.starttime = 0;
            options.stoptime = 0;

            string srtfile = null;
            foreach (string param in queryarray) {
                if (param.has_prefix("start=")) {
                    options.starttime = int.parse(param.split("=")[1]);
                }
                if (param.has_prefix("stop=")) {
                    options.stoptime = int.parse(param.split("=")[1]);
                }
                if (param.has_prefix("srtfile=")) {
                    srtfile = param.split("=")[1];
                }
            }
            string uri = filename_to_uri(file, controller.get_pdf_fname());
            string suburi;
            if (srtfile != null) {
                suburi = filename_to_uri(srtfile, controller.get_pdf_fname());
            } else {
                suburi = null;
            }
            bool uncertain;
            string ctype = GLib.ContentType.guess(uri, null, out uncertain);
            if (!("video" in ctype) &&
                !("video" in GLib.ContentType.get_mime_type(ctype))) {
                return null;
            }

            Type type = Type.from_instance(this);
            ControlledMovie new_obj = (ControlledMovie) GLib.Object.new(type);
            this.init_movie(new_obj, mapping.area, controller, uri,
                suburi, options);
            return new_obj;
        }

        /**
         * Create a new Movie from an annotation mapping, if the annotation is a
         * screen annotation with a video file or a movie annotation.  Some
         * options to modify the behavior of the playback are not yet supported,
         * since they're missing from poppler.
         */
        protected override ActionMapping? new_from_annot_mapping(Poppler.AnnotMapping mapping,
                PresentationController controller) {
            Poppler.Annot annot = mapping.annot;
            string uri, suburi = null;
            bool temp = false;
            string file = null;

            options.autostart = false;
            options.loop = false;
            options.noprogress = false;
            options.noaudio = false;
            options.poster = false;
            options.starttime = 0;
            options.stoptime = 0;

            switch (annot.get_annot_type()) {
            case Poppler.AnnotType.SCREEN:
                if (!("video" in annot.get_contents())) {
                    return null;
                }

                Poppler.Action action = ((Poppler.AnnotScreen) annot).get_action();
                Poppler.Media movie = (Poppler.Media) action.movie.movie;

                if (movie.is_embedded()) {
                    string tmp_fn;
                    int fh;
                    try {
                        fh = FileUtils.open_tmp("pdfpc-XXXXXX", out tmp_fn);
                    } catch (FileError e) {
                        GLib.printerr("Could not create temp file: %s\n", e.message);
                        return null;
                    }
                    FileUtils.close(fh);
                    try {
                        movie.save(tmp_fn);
                    } catch (Error e) {
                        GLib.printerr("Could not save temp file: %s\n", e.message);
                        return null;
                    }
                    uri = "file://" + tmp_fn;
                    temp = true;
                } else {
                    file = movie.get_filename();
                    if (file == null) {
                        GLib.printerr("Movie not embedded and has no file name\n");
                        return null;
                    }
                    uri = filename_to_uri(file, controller.get_pdf_fname());
                    temp = false;
                }
                break;

            case Poppler.AnnotType.MOVIE:
                var movie = ((Poppler.AnnotMovie) annot).get_movie();
                file = movie.get_filename();
                if (file == null) {
                    GLib.printerr("Movie has no file name\n");
                    return null;
                }
                uri = filename_to_uri(file, controller.get_pdf_fname());
                temp = false;
                options.poster = movie.need_poster();
                options.noprogress = !movie.show_controls();
                options.loop = movie.get_play_mode() == Poppler.MoviePlayMode.REPEAT;
                options.starttime = (int) (movie.get_start()/1000000000L);
                int duration = (int) (movie.get_duration()/1000000000L);
                if (duration > 0) {
                    options.stoptime = options.starttime + duration;
                }
                break;

            default:
                return null;
            }

            Type type = Type.from_instance(this);
            ControlledMovie new_obj = (ControlledMovie) GLib.Object.new(type);
            new_obj.filename = file;

            this.init_movie(new_obj, mapping.area, controller, uri,
                suburi, options, temp);
            return new_obj;
        }

        /**
         * When we leave the page, stop the movie and delete any temporary files.
         */
        protected override void deactivate() {
            this.stop();
            if (this.temp != "") {
                if (FileUtils.unlink(this.temp) != 0) {
                    GLib.printerr("Problem deleting temp file %s\n", this.temp);
                }
            }

            foreach (var sink in this.sinks) {
                var parent = sink.parent as View.Video;
                parent.remove_video(sink);
            }
        }

        /**
         * Hide all video widegts (but receive events for them)
         */
        public void hide() {
            foreach (var sink in this.sinks) {
                sink.set_opacity(0);
            }
            this.shown = false;
        }

        private void update_cursor(Gdk.Window window) {
            Gdk.Cursor cursor;
            if (this.in_seek_bar) {
                cursor = this.drag_cursor;
            } else
            if (this.paused_at >= 0) {
                cursor = this.play_cursor;
            } else {
                cursor = this.pause_cursor;
            }
            window.set_cursor(cursor);
        }

        /**
         * If we click outside of the progress bar, toggle the playing state.
         * Inside the progress bar, pause or stop the timeout, and start the
         * drag state.
         */
        protected override bool on_button_press(Gtk.Widget widget, Gdk.EventButton event) {
            if (this.pipeline == null) {
                return false;
            }

            this.update_cursor(event.window);

            this.set_mouse_in(event.x, event.y);
            if (!this.in_seek_bar) {
                this.toggle_play();
            } else {
                this.mouse_drag = true;
                this.drag_was_playing = (this.pipeline.current_state == Gst.State.PLAYING);
                this.pause();
                this.mouse_seek(event.x, event.y);
            }

            return true;
        }

        /**
         * Stop the drag state and restart either playback or the timeout,
         * depending on the previous state.
         */
        protected override bool on_button_release(Gtk.Widget widget, Gdk.EventButton event) {
            this.update_cursor(event.window);

            this.set_mouse_in(event.x, event.y);
            if (this.mouse_drag) {
                var seek_time = this.mouse_seek(event.x, event.y);
                if (this.drag_was_playing || this.eos) {
                    this.eos = false;
                    this.play();
                } else {
                    this.pipeline.seek_simple(Gst.Format.TIME, Gst.SeekFlags.FLUSH, seek_time);
                }
            }
            this.mouse_drag = false;

            return true;
        }

       /**
         * Load a cursor
         */
        protected Gdk.Cursor load_cursor(Gdk.Display display, string filename) {
            Gdk.Cursor cursor;
            int size = 24;
            var surface = Renderer.Image.render(filename, size, size);
            if (surface != null) {
                cursor = new Gdk.Cursor.from_surface(display, surface, 0, 0);
            } else {
                cursor = new Gdk.Cursor.from_name(display, "default");
            }
            return cursor;
        }

        /**
         * Force refresh when not playing
         */
        protected void refresh() {
            if (this.paused_at >= 0 || this.eos) {
                this.pipeline.seek_simple(Gst.Format.TIME, Gst.SeekFlags.FLUSH,
                    this.paused_at);
            }
        }

        protected override void on_mouse_leave(Gtk.Widget widget, Gdk.EventMotion event) {
            this.in_seek_bar = false;
            this.mouse_drag = false;
            this.refresh();
        }

        protected override void on_freeze(bool frozen) {
            // if a video was forcefully hidden but we're no longer in the
            // freeze mode, show it and clear the respective flag
            foreach (var sink in this.sinks) {
                bool sink_is_frozen = sink.get_data("pdfpc_frozen");
                if (!frozen && sink_is_frozen) {
                    sink.set_opacity(1);
                    sink.set_data("pdfpc_frozen", false);
                }
            }

            return;
        }

        /**
         * Everytime we get a new frame, update the progress bar.
         */
        public void on_draw(Gst.Element overlay, Cairo.Context cr, uint64 timestamp,
                uint64 duration) {
            // Transform to work from bottom left, in screen coordinates
            cr.translate(0, this.video_h);
            cr.scale(this.scalex, -this.scaley);

            this.draw_seek_bar(cr, timestamp);

            // if a stop time is defined, stop there (but still let
            // the user manually seek *after* this timestamp)
            if (this.options.stoptime != 0 &&
                this.options.stoptime * Gst.SECOND < timestamp &&
                timestamp < (this.options.stoptime + 0.2) * Gst.SECOND) {
                if (this.options.loop) {
                    // attempting to seek from this callback fails, so we
                    // must schedule a seek on next idle time.
                    GLib.Idle.add(() => {
                        this.pipeline.seek_simple(Gst.Format.TIME, Gst.SeekFlags.FLUSH,
                            this.options.starttime*Gst.SECOND);
                        return false;
                    });
                } else {
                    // Can't seek to beginning w/o updating output, so mark to seek later
                    this.eos = true;
                    this.pause();
                }
            }

        }

        /**
         * Handling of bus messages on the Gstreamer pipeline.
         */
        public void on_gst_message(Gst.Message message) {
            switch (message.type) {
            case Gst.MessageType.EOS:
                if (this.options.loop) {
                    this.pipeline.seek_simple(Gst.Format.TIME,
                        Gst.SeekFlags.FLUSH, this.options.starttime*Gst.SECOND);
                } else {
                    // Can't seek to beginning w/o updating output,
                    // so mark to seek later
                    this.eos = true;
                    this.pause();
                }
                break;
            case Gst.MessageType.ERROR:
                GLib.Error err;
                string debug_info;
                message.parse_error(out err, out debug_info);
                GLib.printerr("Gstreamer error from element %s: %s\n",
                    message.src.name, err.message);
                if (debug_info != null) {
                    GLib.printerr("  (debugging info: %s)\n", debug_info);
                }
                break;
            default:
                break;
            }
        }

        /**
         * Seek if we're dragging the progress bar.
         */
        protected override bool on_mouse_move(Gtk.Widget widget, Gdk.EventMotion event) {
            this.set_mouse_in(event.x, event.y);

            this.update_cursor(event.window);

            if (this.mouse_drag) {
                this.mouse_seek(event.x, event.y);
            } else {
                this.refresh();
            }

            return false;
        }

        /**
         * When we find out the properties of the movie, we can work out how it
         * needs to be scaled to fit in the alloted area.  (This is only important
         * for the view with the controls.)
         */
        public void on_prepare(Gst.Element overlay, Gst.Caps caps) {
            var info = new Gst.Video.Info();
            info.from_caps(caps);
            this.video_w = info.width;
            this.video_h = info.height;
            this.scalex = (double) this.video_w/rect.width;
            this.scaley = (double) this.video_h/rect.height;
            this.seek_bar_height = (this.seek_bar_fontsize +
                2*seek_bar_padding)/this.scaley;

            overlay.query_duration(Gst.Format.TIME, out duration);
        }

        /**
         * Show all video widgets except those created while the view was frozen
         */
        public void show() {
            foreach (var sink in this.sinks) {
                bool sink_is_frozen = sink.get_data("pdfpc_frozen");
                if (!sink_is_frozen) {
                    sink.set_opacity(1);
                }
            }
            this.shown = true;
        }

        protected void draw_seek_bar(Cairo.Context cr, uint64 timestamp) {
            double start = (double) options.starttime*Gst.SECOND/this.duration;
            double stop = (double) options.stoptime*Gst.SECOND/this.duration;

            // special case: only starttime is defined
            if (options.starttime != 0 && options.stoptime == 0) {
                stop = 1.0;
            }

            var start_bar = start * rect.width;
            var stop_bar = stop * rect.width;

            double fraction = (double) timestamp / this.duration;
            if (this.in_seek_bar || this.mouse_drag) {
                double bar_end = fraction * (rect.width - 2 * this.seek_bar_padding);
                cr.rectangle(0, 0, rect.width, this.seek_bar_height);
                cr.set_source_rgba(0, 0, 0, 0.8);
                cr.fill();
                cr.rectangle(this.seek_bar_padding, this.seek_bar_padding,
                    bar_end, this.seek_bar_height-4);
                cr.set_source_rgba(1, 1, 1, 0.8);
                cr.fill();
                cr.rectangle(start_bar, 0, stop_bar - start_bar, this.seek_bar_height);
                cr.set_source_rgba(0,1,0,0.5);
                cr.fill();

                int time_in_sec = (int) (timestamp / Gst.SECOND);
                string timestring = "%i:%02i".printf(time_in_sec / 60, time_in_sec % 60);
                int dur_in_sec = (int) (this.duration / Gst.SECOND);
                string durstring = "%i:%02i".printf(dur_in_sec / 60, dur_in_sec % 60);
                Cairo.TextExtents te;
                Cairo.FontOptions fo = new Cairo.FontOptions();
                fo.set_antialias(Cairo.Antialias.GRAY);
                cr.set_font_options(fo);
                cr.select_font_face("sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
                cr.set_font_size(this.seek_bar_height - 2 * seek_bar_padding);

                cr.text_extents(durstring, out te);
                if ((bar_end + te.width + 4 * this.seek_bar_padding) < rect.width) {
                    cr.move_to(rect.width - te.width - 2 * this.seek_bar_padding,
                        this.seek_bar_height / 2 - te.height / 2);
                    cr.set_source_rgba(0.8, 0.8, 0.8, 1);
                    cr.save();
                    cr.scale(1, -1);
                    cr.show_text(durstring);
                    cr.restore();
                }

                cr.text_extents(timestring, out te);
                if (bar_end > te.width) {
                    cr.move_to(bar_end - te.width, this.seek_bar_height / 2 - te.height / 2);
                    cr.set_source_rgba(0, 0, 0, 1);
                } else {
                    cr.move_to(bar_end + 2 * this.seek_bar_padding,
                        this.seek_bar_height / 2 - te.height / 2);
                    cr.set_source_rgba(0.8, 0.8, 0.8, 1);
                }
                cr.save();
                cr.scale(1, -1);
                cr.show_text(timestring);
                cr.restore();

            } else if (this.options.noprogress == false) {
                cr.rectangle(0, 0, rect.width, 4);
                cr.set_source_rgba(0, 0, 0, 0.8);
                cr.fill();
                cr.rectangle(1, 1, fraction * (rect.width - 2), 2);
                cr.set_source_rgba(1, 1, 1, 0.8);
                cr.fill();
                cr.rectangle(start_bar, 0, stop_bar - start_bar, 4);
                cr.set_source_rgba(1,1,1,0.5);
                cr.fill();
            }
        }

        /**
         * Set up the gstreamer pipeline.
         */
        protected void establish_pipeline(string uri, string? suburi) {
            this.pipeline = null;

            Gst.Bin bin = new Gst.Bin("bin");
            Gst.Element tee = Gst.ElementFactory.make("tee", "tee");
            bin.add_many(tee);
            bin.add_pad(new Gst.GhostPad("sink", tee.get_static_pad("sink")));
            int n = 0;

            Gee.List<VideoConf> video_confs = new Gee.ArrayList<VideoConf>();
            while (true) {
                Gdk.Rectangle rect;
                Window.ControllableWindow window;
                this.controller.overlay_pos(n, this.area, out rect, out window);
                if (window == null) {
                    break;
                }
                VideoConf conf = new VideoConf() {
                    display_num = n,
                    rect = rect,
                    window = window
                };
                video_confs.add(conf);

                n++;
            }

            n = 0;
            foreach (var conf in video_confs) {
                Gst.Element sink;
                try {
                    sink = gst_element_make("gtksink", @"sink$n");
                } catch (PipelineError e) {
                    GLib.printerr("Error creating video sink: %s\n", e.message);
                    GLib.printerr("Gstreamer installation may be incomplete.\n");
                    return;
                }

                Gtk.Widget video_area;
                sink.get("widget", out video_area);
                Gst.Element queue = Gst.ElementFactory.make("queue", @"queue$n");
                bin.add_many(queue, sink);
                tee.link(queue);
                if (conf.window.interactive) {
                    Gst.Element ad_element = this.add_video_control(queue, bin,
                        conf.rect);
                    ad_element.link(sink);
                } else {
                    queue.link(sink);
                }
                sink.set("force_aspect_ratio", false);

                // mark the video widget on the "frozen" presentation screen
                // with a custom flag
                if (!conf.window.interactive && controller.frozen) {
                    video_area.set_data("pdfpc_frozen", true);
                }

                var video_surface = conf.window.video_surface;
                video_surface.add_video(video_area, conf.rect);
                video_surface.size_allocate.connect((a) => {
                        Gdk.Rectangle rect;
                        Window.ControllableWindow window;

                        this.controller.overlay_pos(conf.display_num,
                            this.area, out rect, out window);

                        // Update the rectangle
                        conf.rect = rect;
                        if (window.interactive) {
                            this.rect = rect;
                            this.scalex = (double) this.video_w/rect.width;
                            this.scaley = (double) this.video_h/rect.height;
                            this.seek_bar_height = (this.seek_bar_fontsize +
                                2*seek_bar_padding)/this.scaley;
                        }
                        video_surface.resize_video(video_area, rect);
                    });
                this.sinks.add(video_area);

                n++;
            }

            this.pipeline = Gst.ElementFactory.make("playbin", "playbin");
            this.pipeline.set("uri", uri);
            if (suburi != null) {
                this.pipeline.set("suburi", suburi);
            } else if (Options.auto_srt) {
                this.pipeline.set("suburi", uri + ".srt");
            }
            // Make the fontsize adjustable?
            int subsize = 18;
            this.pipeline.set("subtitle-font-desc", @"Sans, $subsize");
            this.pipeline.set("force_aspect_ratio", false);  // Else overrides last overlay
            this.pipeline.set("video_sink", bin);
            this.pipeline.set("mute", this.options.noaudio);

            Gst.Bus bus = this.pipeline.get_bus();
            bus.add_signal_watch();
            bus.message.connect(this.on_gst_message);

            Gst.Debug.bin_to_dot_file(bin, Gst.DebugGraphDetails.ALL, "pipeline");
        }

        /**
         * Utility function for converting filenames to URI's. If file
         * is not an absolute path, use the PDF file location as a base
         * directory.
         */
        protected string filename_to_uri(string location, string pdf_fname) {
            if (Uri.parse_scheme(location) != null) {
                return location;
            }

            string fullpath;
            if (GLib.Path.is_absolute(location)) {
                fullpath = location;
            } else {
                var dirname = GLib.Path.get_dirname(pdf_fname);
                fullpath = GLib.Path.build_filename(dirname, location);
            }

            var fp = File.new_for_path(fullpath);
            return fp.get_uri();
        }

        /**
         * Hook up the elements to draw the controls to the first output leg.
         */
        protected Gst.Element add_video_control(Gst.Element source, Gst.Bin bin,
            Gdk.Rectangle rect) {
            dynamic Gst.Element overlay;
            Gst.Element adaptor;
            try {
                adaptor = gst_element_make("videoconvert", "converter");
                overlay = gst_element_make("cairooverlay", "controls");
                bin.add_many(adaptor, overlay);
                if (!source.link_many(overlay, adaptor)) {
                    throw new PipelineError.Linking("Could not link pipeline.");
                }
            } catch (PipelineError err) {
                GLib.printerr("Error creating control pipeline: %s\n",
                    err.message);
                return source;
            }

            this.rect = rect;
            overlay.draw.connect(this.on_draw);
            overlay.caps_changed.connect(this.on_prepare);

            return adaptor;
        }

        /**
         * Seek to the time indicated by the mouse position on the progress bar.
         */
        protected int64 mouse_seek(double x, double y) {
            // shift by the widget offset
            x -= rect.x;
            double seek_fraction = (x - this.seek_bar_padding) / (rect.width -
                2 * this.seek_bar_padding);
            if (seek_fraction < 0) {
                seek_fraction = 0;
            }
            if (seek_fraction > 1) {
                seek_fraction = 1;
            }
            int64 seek_time = (int64) (seek_fraction * this.duration);
            this.pipeline.seek_simple(Gst.Format.TIME, Gst.SeekFlags.FLUSH, seek_time);
            if (this.paused_at >= 0) {
                this.paused_at = seek_time;
            }
            return seek_time;
        }

        /**
         * Set a flag about whether the mouse is currently in the progress bar.
         */
        private void set_mouse_in(double x, double y) {
            // shift coordinates by the widget offsets
            x -= this.rect.x;
            y -= this.rect.y;
            this.in_seek_bar =
                this.shown &&
                x > 0 &&
                x < this.rect.width &&
                y > this.rect.height - this.seek_bar_height &&
                y < this.rect.height;
        }

        /**
         * Play the movie, rewinding to the beginning if we had reached the
         * end.
         */
        public void play() {
            // force showing the widgets
            this.show();

            this.paused_at = -1;

            if (this.eos) {
                this.eos = false;
                this.pipeline.seek_simple(Gst.Format.TIME,
                    Gst.SeekFlags.FLUSH, this.options.starttime*Gst.SECOND);
            }
            this.pipeline.set_state(Gst.State.PLAYING);
        }

        /**
         * Pause playback.
         */
        public void pause() {
            this.pipeline.set_state(Gst.State.PAUSED);

            this.pipeline.query_position(Gst.Format.TIME, out this.paused_at);
            if (this.eos) {
                this.paused_at -= 1;
            }
        }

        /**
         * Rewind.
         */
        public void rewind() {
            this.paused_at = this.options.starttime*Gst.SECOND;
            this.mouse_drag = false;
            this.pipeline.seek_simple(Gst.Format.TIME,
                Gst.SeekFlags.FLUSH, this.options.starttime*Gst.SECOND);
        }

        /**
         * Stop playback.
         */
        public virtual void stop() {
            if (this.pipeline != null) {
                this.pipeline.set_state(Gst.State.NULL);
            }
        }

        /**
         * Pause if playing, and vice versa.
         */
        protected void toggle_play() {
            Gst.State state;
            Gst.ClockTime time = Gst.Util.get_timestamp();
            this.pipeline.get_state(out state, null, time);
            if (state == Gst.State.PLAYING) {
                this.pause();
            } else {
                this.play();
            }
        }
    }
}
