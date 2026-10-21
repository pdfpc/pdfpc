/**
 * Out-of-process slide renderer
 *
 * This file is part of pdfpc.
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
     * Whether and when the helper compresses a rendered page (as PNG) for
     * the cache
     */
    public enum HelperCompress {
        NEVER,
        ALWAYS,
        IF_SLOW
    }

    /**
     * A render job as sent to the helper process
     */
    struct HelperJob {
        int32 slide_number;
        int32 width;
        int32 height;
        int32 compress;
        double compress_min_rtime;
        double scaling_factor;
        double x_offset;
        double y_offset;
    }

    /**
     * Header of the helper's reply; if status is 0, it is followed by
     * stride*height bytes of RGB24 pixel data and png_size bytes of PNG data
     */
    struct HelperReply {
        int32 status;
        int32 width;
        int32 height;
        int32 stride;
        int32 png_size;
        double rtime;
    }

    /**
     * Renders slides in a separate process.
     *
     * Rendering in a thread of the main process is not safe: Poppler shares
     * one FreeType library among all documents, which needs to be locked
     * around face creation and destruction; but faces are destroyed by
     * cairo's font cache eviction, which may happen in any thread using
     * cairo, e.g., in GTK drawing text. A helper process has FreeType and
     * cairo for its own, and can't take the presentation down if it
     * crashes.
     *
     * The helper is pdfpc itself, started as
     *   pdfpc --render-helper <protocol> <uri>
     * It reads HelperJob structs from stdin and replies to each of them on
     * stdout, one at a time. Both are a socket, which, unlike a pipe, does
     * not raise SIGPIPE in pdfpc if the helper dies. The PDF file is passed
     * as an open file descriptor, so that the helper renders exactly the
     * file pdfpc has loaded, even if it has been replaced meanwhile.
     */
    public class Helper : Object {
        /**
         * Command line flag starting the helper mode
         */
        public const string FLAG = "--render-helper";

        /**
         * Version of the protocol; increase on changes
         */
        protected const int PROTOCOL_VERSION = 1;

        /**
         * File descriptor of the PDF file in the helper process
         */
        protected const int DOCUMENT_FD = 3;

        /**
         * Rendering a page longer than this [s] is considered hanging
         */
        protected const uint RENDER_TIMEOUT = 30;

        /**
         * The pdfpc executable, set up by init()
         */
        protected static string? executable = null;

        protected GLib.Pid pid;
        protected GLib.Socket socket;
        protected GLib.SocketConnection connection;
        protected GLib.OutputStream to_helper;
        protected GLib.InputStream from_helper;

        /**
         * Whether the helper process has been terminated or has failed
         */
        public bool dead { get; protected set; default = false; }

        /**
         * Whether the helper has been terminated because rendering a page
         * took too long
         */
        public bool timed_out { get; protected set; default = false; }

        /**
         * Find out the path of our executable, so that it can be started
         * as helper; to be called on startup, before the working directory
         * is changed.
         */
        public static void init(string argv0) {
#if !WIN32
            if (GLib.FileUtils.test("/proc/self/exe", GLib.FileTest.EXISTS)) {
                // Refers to the running binary, even if it gets replaced
                // (e.g., by an update) while pdfpc is running
                executable = "/proc/self/exe";
            } else if (argv0.contains(GLib.Path.DIR_SEPARATOR_S)) {
                executable = File.new_for_path(argv0).get_path();
            } else {
                executable = GLib.Environment.find_program_in_path(argv0);
            }
#endif
        }

        /**
         * Whether helpers can be used; if not, slides are rendered
         * in-process
         */
        public static bool is_supported() {
            return executable != null;
        }

        /**
         * Identifies the protocol, to make sure the helper speaks the same
         */
        protected static string protocol_id() {
            return "%d:%d:%d".printf(PROTOCOL_VERSION,
                (int) sizeof(HelperJob), (int) sizeof(HelperReply));
        }

        /**
         * Start a helper process rendering the document opened as
         * document_fd (which stays owned by the caller)
         */
        public Helper(int document_fd) throws GLib.Error {
#if WIN32
            throw new GLib.IOError.NOT_SUPPORTED(
                "render helpers are not supported on Windows");
#else
            int[] sv = new int[2];
            if (Posix.socketpair(Posix.AF_UNIX, Posix.SOCK_STREAM, 0, sv) != 0) {
                throw new GLib.IOError.FAILED("socketpair: %s",
                    GLib.strerror(GLib.errno));
            }

            string[] argv = {
                executable, FLAG, protocol_id(),
                "file:///dev/fd/%d".printf(DOCUMENT_FD)
            };
            try {
                GLib.Process.spawn_async_with_pipes_and_fds(null, argv, null,
                    GLib.SpawnFlags.DO_NOT_REAP_CHILD, null,
                    sv[1], sv[1], -1,
                    { document_fd }, { DOCUMENT_FD },
                    out this.pid);
            } catch (GLib.SpawnError e) {
                Posix.close(sv[0]);
                Posix.close(sv[1]);
                throw e;
            }
            Posix.close(sv[1]);

            GLib.ChildWatch.add(this.pid, (pid, status) => {
                    GLib.Process.close_pid(pid);
                });

            // Keep the connection, its streams get closed when it goes away
            this.socket = new GLib.Socket.from_fd(sv[0]);
            this.connection =
                GLib.SocketConnection.factory_create_connection(this.socket);
            this.to_helper = this.connection.output_stream;
            this.from_helper = this.connection.input_stream;
#endif
        }

        /**
         * Stop the helper process; a pending render() fails
         */
        public void terminate() {
#if !WIN32
            if (!this.dead) {
                this.dead = true;
                Posix.kill(this.pid, Posix.Signal.KILL);
                try {
                    this.socket.close();
                } catch (GLib.Error e) {
                    // nothing to do
                }
            }
#endif
        }

        /**
         * Render a page in the helper process. Returns null if the page
         * could not be rendered; throws if the helper failed (the helper is
         * terminated then).
         *
         * The PNG-compressed page is returned in png if the helper has been
         * asked to compress it for the cache.
         */
        public async Cairo.ImageSurface? render(int slide_number,
            int width, int height,
            double scaling_factor, double x_offset, double y_offset,
            HelperCompress compress, double compress_min_rtime,
            out double rtime, out GLib.Bytes? png) throws GLib.Error {
            rtime = 0;
            png = null;

            if (this.dead) {
                throw new GLib.IOError.CLOSED("render helper has exited");
            }

            // Watchdog against pages hanging the helper
            uint timeout_id = 0;
            timeout_id = GLib.Timeout.add_seconds(RENDER_TIMEOUT, () => {
                    timeout_id = 0;
                    this.timed_out = true;
                    this.terminate();
                    return GLib.Source.REMOVE;
                });

            try {
                var job = HelperJob() {
                    slide_number = slide_number,
                    width = width,
                    height = height,
                    compress = compress,
                    compress_min_rtime = compress_min_rtime,
                    scaling_factor = scaling_factor,
                    x_offset = x_offset,
                    y_offset = y_offset
                };
                unowned uint8[] job_data = (uint8[]) (&job);
                job_data.length = (int) sizeof(HelperJob);
                size_t n;
                yield this.to_helper.write_all_async(job_data,
                    GLib.Priority.DEFAULT, null, out n);

                var reply = HelperReply();
                unowned uint8[] reply_data = (uint8[]) (&reply);
                reply_data.length = (int) sizeof(HelperReply);
                yield this.read_fully(reply_data);
                if (reply.status != 0) {
                    return null;
                }

                var surface = new Cairo.ImageSurface(Cairo.Format.RGB24,
                    width, height);
                if (reply.width != width || reply.height != height ||
                    reply.stride != surface.get_stride() ||
                    reply.png_size < 0) {
                    throw new GLib.IOError.INVALID_DATA(
                        "render helper replied with a wrong format");
                }

                // Read the pixels directly into the surface
                surface.flush();
                unowned uint8[] pixels = surface.get_data();
                pixels.length = reply.stride*reply.height;
                yield this.read_fully(pixels);
                surface.mark_dirty();

                if (reply.png_size > 0) {
                    var png_data = new uint8[reply.png_size];
                    yield this.read_fully(png_data);
                    png = new GLib.Bytes.take((owned) png_data);
                }

                rtime = reply.rtime;
                return surface;
            } catch (GLib.Error e) {
                this.terminate();
                throw e;
            } finally {
                if (timeout_id != 0) {
                    GLib.Source.remove(timeout_id);
                }
            }
        }

        /**
         * Read exactly buf.length bytes from the helper
         */
        private async void read_fully(uint8[] buf) throws GLib.Error {
            size_t n;
            yield this.from_helper.read_all_async(buf, GLib.Priority.DEFAULT,
                null, out n);
            if (n != buf.length) {
                throw new GLib.IOError.BROKEN_PIPE(
                    "render helper exited unexpectedly");
            }
        }

        /**
         * Read exactly buf.length bytes from stdin (in the helper process);
         * false on end of file
         */
        private static bool read_stdin(uint8[] buf) {
            size_t total = 0;
            while (total < buf.length) {
                unowned uint8[] rest = buf[total:buf.length];
                size_t n = GLib.stdin.read(rest);
                if (n == 0) {
                    return false;
                }
                total += n;
            }
            return true;
        }

        /**
         * Main loop of the helper process
         */
        public static int serve(string protocol, string uri) {
            if (protocol != protocol_id()) {
                GLib.printerr("Render helper: protocol mismatch (%s vs. %s)\n",
                    protocol, protocol_id());
                return 2;
            }

            Poppler.Document document;
            try {
                document = new Poppler.Document.from_file(uri, null);
            } catch (GLib.Error e) {
                GLib.printerr("Render helper: unable to open %s: %s\n",
                    uri, e.message);
                return 1;
            }

            var job = HelperJob();
            unowned uint8[] job_data = (uint8[]) (&job);
            job_data.length = (int) sizeof(HelperJob);

            while (read_stdin(job_data)) {
                var reply = HelperReply();
                unowned uint8[] reply_data = (uint8[]) (&reply);
                reply_data.length = (int) sizeof(HelperReply);

                Poppler.Page? page = null;
                if (job.width > 0 && job.height > 0 && job.slide_number >= 0 &&
                    job.slide_number < document.get_n_pages()) {
                    page = document.get_page(job.slide_number);
                }
                if (page == null) {
                    reply.status = 1;
                    GLib.stdout.write(reply_data);
                    GLib.stdout.flush();
                    continue;
                }

                double rtime;
                var surface = Renderer.Pdf.render_page(page,
                    job.width, job.height, job.scaling_factor,
                    job.x_offset, job.y_offset, out rtime);
                surface.flush();

                uint8[]? png_data = null;
                if (job.compress == HelperCompress.ALWAYS ||
                    (job.compress == HelperCompress.IF_SLOW &&
                     rtime > job.compress_min_rtime)) {
                    png_data = Renderer.Cache.compress(surface);
                }

                reply.status = 0;
                reply.width = job.width;
                reply.height = job.height;
                reply.stride = surface.get_stride();
                reply.png_size = (png_data != null) ? png_data.length : 0;
                reply.rtime = rtime;

                unowned uint8[] pixels = surface.get_data();
                pixels.length = reply.stride*reply.height;
                if (GLib.stdout.write(reply_data) != reply_data.length ||
                    GLib.stdout.write(pixels) != pixels.length ||
                    (png_data != null &&
                     GLib.stdout.write(png_data) != png_data.length)) {
                    // pdfpc has gone away
                    return 0;
                }
                GLib.stdout.flush();
            }

            return 0;
        }
    }
}
