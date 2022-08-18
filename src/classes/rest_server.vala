/**
 * REST server
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2020 Evgeny Stambulchik
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
    public class RestServer : Soup.Server {
        private int api_version = 1;
        private Metadata.Pdf metadata;
        private int port_num;
        private bool locked = false;
        private string? client_host = null;
        private string static_root = ".";

        private Json.Node helo_data() {
            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            builder.set_member_name("application");
            builder.add_string_value("pdfpc");
            builder.set_member_name("api");
            builder.add_int_value(this.api_version);

            builder.end_object();
            return builder.get_root();
        }

        private Json.Node meta_data() {
            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            builder.set_member_name("slides");
            builder.add_int_value(metadata.get_slide_count());
            builder.set_member_name("user_slides");
            builder.add_int_value(metadata.get_user_slide_count());

            builder.set_member_name("duration");
            builder.add_int_value(metadata.get_duration());
            builder.set_member_name("end_time");
            builder.add_string_value(Options.end_time);
            builder.set_member_name("start_time");
            builder.add_string_value(Options.start_time);
            builder.set_member_name("last_minutes");
            builder.add_int_value(Options.last_minutes);
            builder.set_member_name("default_transition");
            builder.add_string_value(Options.default_transition);

            double aspect_ratio = metadata.get_page_width()/
                metadata.get_page_height();
            char[] buf = new char[double.DTOSTR_BUF_SIZE];

            builder.set_member_name("aspect_ratio");
            builder.add_string_value(aspect_ratio.format(buf, "%.4f"));

            builder.set_member_name("note_is_image");
            builder.add_boolean_value(metadata.has_beamer_notes);

            builder.end_object();
            return builder.get_root();
        }

        private Json.Node error_data(string message) {
            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            builder.set_member_name("message");
            builder.add_string_value(message);

            builder.end_object();
            return builder.get_root();
        }

        private Json.Node pointer_data() {
            var controller = this.metadata.controller;

            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            builder.set_member_name("mode");
            builder.add_string_value(controller.get_mode_string());

            builder.set_member_name("x");
            builder.add_double_value(controller.pointer_x);
            builder.set_member_name("y");
            builder.add_double_value(controller.pointer_y);

            builder.end_object();
            return builder.get_root();
        }

        private Json.Node state_data() {
            var controller = this.metadata.controller;

            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            string statestr;
            builder.set_member_name("state");
            if (controller.is_running()) {
                statestr = "running";
            } else if (controller.is_paused()) {
                statestr = "paused";
            } else {
                statestr = "stopped";
            }
            builder.add_string_value(statestr);

            builder.set_member_name("progress_status");
            string progress_status_str;
            switch (controller.progress_status) {
            case PresentationController.ProgressStatus.PreTalk:
                progress_status_str = "pretalk";
                break;
            case PresentationController.ProgressStatus.Fast:
                progress_status_str = "too-fast";
                break;
            case PresentationController.ProgressStatus.Slow:
                progress_status_str = "too-slow";
                break;
            case PresentationController.ProgressStatus.LastMinutes:
                progress_status_str = "last-minutes";
                break;
            case PresentationController.ProgressStatus.Overtime:
                progress_status_str = "overtime";
                break;
            default:
                progress_status_str = "normal";
                break;
            }
            builder.add_string_value(progress_status_str);

            builder.set_member_name("mode");
            builder.add_string_value(controller.get_mode_string());

            builder.set_member_name("frozen");
            builder.add_boolean_value(controller.frozen);
            builder.set_member_name("hidden");
            builder.add_boolean_value(controller.hidden);
            builder.set_member_name("black");
            builder.add_boolean_value(controller.faded_to_black);

            builder.set_member_name("slide");
            builder.add_int_value(controller.current_slide_number);
            builder.set_member_name("user_slide");
            builder.add_int_value(controller.current_user_slide_number);
            builder.set_member_name("end_user_slide");
            builder.add_int_value(metadata.get_end_user_slide());

            builder.set_member_name("note_font_size");
            builder.add_int_value(metadata.get_font_size());

            builder.set_member_name("in_zoom");
            builder.add_boolean_value(controller.in_zoom);

            builder.set_member_name("highlighted_area");
            builder.begin_object();
            builder.set_member_name("x");
            builder.add_double_value(controller.highlight.x);
            builder.set_member_name("y");
            builder.add_double_value(controller.highlight.y);
            builder.set_member_name("width");
            builder.add_double_value(controller.highlight.width);
            builder.set_member_name("height");
            builder.add_double_value(controller.highlight.height);
            builder.end_object();

            builder.end_object();
            return builder.get_root();
        }

        private Json.Node slide_data(int slide_number) {
            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            var user_slide = metadata.real_slide_to_user_slide(slide_number);
            builder.set_member_name("user_slide");
            builder.add_int_value(user_slide);

            builder.set_member_name("image_url");
            builder.add_string_value("/api/slides/" + slide_number.to_string() +
                "/image");

            builder.set_member_name("note_url");
            builder.add_string_value("/api/notes/" + slide_number.to_string());

            builder.end_object();
            return builder.get_root();
        }

        private Json.Node note_data(int slide_number) {
            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            var basestr = "/api/notes/" + slide_number.to_string();
            if (this.metadata.has_beamer_notes) {
                builder.set_member_name("image_url");
                builder.add_string_value(basestr + "/image");
            } else {
                builder.set_member_name("raw_url");
                builder.add_string_value(basestr + "/raw");

                builder.set_member_name("html_url");
                builder.add_string_value(basestr + "/html");
            }

            builder.end_object();
            return builder.get_root();
        }


        private uint8[]? get_slide_png(int slide_number, int width, int height,
            bool notes_area = false) {
            try {
                var surface = metadata.renderer.render(slide_number,
                    notes_area, width, height);

                var pixbuf = Gdk.pixbuf_get_from_surface(surface,
                0, 0, surface.get_width(), surface.get_height());
                uint8[] png_data;
                pixbuf.save_to_buffer(out png_data,
                    "png", "compression", "1", null);
                return png_data;
            } catch (Error e) {
                return null;
            }
        }

        private void static_handler(Soup.Server server, Soup.Message msg,
            string path, GLib.HashTable? query, Soup.ClientContext client) {

	    var fname = this.static_root + msg.uri.get_path();
            if (fname.has_suffix("/")) {
                fname += "index.html";
            }

            uint8[] raw_datau8;
            var file = File.new_for_path(fname);

            try {
                file.load_contents(null, out raw_datau8, null);

                bool result_uncertain;
                var mime = GLib.ContentType.guess(fname, raw_datau8,
                    out result_uncertain);
                msg.set_response(mime, Soup.MemoryUse.COPY, raw_datau8);

                msg.status_code = 200;
            } catch (Error e) {
                GLib.printerr("Failed opening file %s: %s\n", fname, e.message);
                msg.status_code = 404;
            }
	}

        private void api_handler(Soup.Server server, Soup.Message msg,
            string path, GLib.HashTable<string, string>? query,
            Soup.ClientContext client) {

            // Once locked, serve only the single client
            if (this.locked && this.client_host != client.get_host()) {
                msg.status_code = 403;
                GLib.printerr("Refused to serve client %s\n",
                    client.get_host());
                return;
            }

            var headers = msg.response_headers;
            headers.append("Access-Control-Allow-Origin", "*");
            headers.append("Access-Control-Allow-Methods", "GET,PUT");
            headers.append("Access-Control-Allow-Headers",
                "authorization,content-type");

            if (msg.method == "OPTIONS") {
                msg.status_code = 204;
                return;
            }

            // This must be the first call of the session
            if (path == "/api/helo") {
                if (!this.locked) {
                    this.locked = true;
                    this.client_host = client.get_host();
                    // At this point the QR code may be withdrawn
                    this.metadata.controller.hide_qrcode();
                }
            } else if (!this.locked) {
                // Anything else is forbidden until "lock-in" is in effect
                msg.status_code = 412;
                return;
            }

            msg.status_code = 200;

            Json.Node root;

            if (path == "/api/helo") {
                root = this.helo_data();
            } else if (path == "/api/state") {
                root = this.state_data();
            } else if (path == "/api/meta") {
                root = this.meta_data();
            } else if (path.has_prefix("/api/slides/")) {
                try {
                    GLib.Regex regex =
                        new GLib.Regex("/api/slides/(\\d+)(/image)?");
                    string[] parts = regex.split(path);
                    int nparts = parts.length;

                    int slide_number = 0;
                    if (nparts < 2) {
                        root = this.error_data("Bad request");
                        msg.status_code = 400;
                    } else {
                        slide_number = int.parse(parts[1]);
                        if (nparts == 4 && query != null) {
                            var wstr = query.get("w");
                            var hstr = query.get("h");
                            if (wstr != null && hstr != null) {
                                var width = int.parse(wstr);
                                var height = int.parse(hstr);
                                if (width > 0 && height > 0) {
                                    var png_data = get_slide_png(slide_number,
                                        width, height);
                                    if (png_data != null) {
                                        msg.set_response("image/png",
                                            Soup.MemoryUse.COPY, png_data);
                                        return;
                                    }
                                }
                            }
                            root = this.error_data("Rendering failed");
                            msg.status_code = 500;
                        } else {
                            root = this.slide_data(slide_number);
                        }
                    }
                } catch (Error e) {
                    root = this.error_data(e.message);
                    msg.status_code = 500;
                }
            } else if (path.has_prefix("/api/notes/")) {
                try {
                    GLib.Regex regex =
                        new GLib.Regex("/api/notes/(\\d+)(/.+)?");
                    string[] parts = regex.split(path);
                    int nparts = parts.length;

                    int slide_number = 0;
                    if (nparts < 2) {
                        root = this.error_data("Bad request");
                        msg.status_code = 400;
                    } else {
                        slide_number = int.parse(parts[1]);
                        if (nparts == 4) {
                            var type = parts[2];
                            switch (type) {
                            case "/html":
                                var note = metadata.get_note(slide_number);
                                var doc = Renderer.MD.render(note,
                                    metadata.get_disable_markdown());
                                msg.set_response("text/html",
                                    Soup.MemoryUse.COPY, doc.data);
                                return;
                            case "/image":
                                string wstr = null, hstr = null;
                                if (query != null) {
                                    wstr = query.get("w");
                                    hstr = query.get("h");
                                }
                                if (wstr != null && hstr != null) {
                                    var width = int.parse(wstr);
                                    var height = int.parse(hstr);
                                    if (width > 0 && height > 0) {
                                        var png_data = get_slide_png(slide_number,
                                            width, height, true);
                                        if (png_data != null) {
                                            msg.set_response("image/png",
                                                Soup.MemoryUse.COPY, png_data);
                                            return;
                                        }
                                    }
                                }
                                root = this.error_data("Rendering failed");
                                msg.status_code = 500;
                                break;
                            default:
                                root = this.error_data("Bad request");
                                msg.status_code = 400;
                                break;
                            }
                        } else {
                            root = this.note_data(slide_number);
                        }
                    }
                } catch (Error e) {
                    root = this.error_data(e.message);
                    msg.status_code = 500;
                }
            } else if (path == "/api/control" && msg.method == "PUT") {
                var body = msg.request_body;
                Json.Parser parser = new Json.Parser();
                try {
                    parser.load_from_data((string) body.data,
                        (ssize_t) body.length);
                    Json.Node node = parser.get_root();
                    if (node != null && node.get_node_type() == Json.NodeType.OBJECT) {
                        unowned Json.Object obj = node.get_object();
                        string action = null, argument = null;
                        foreach (unowned string name in obj.get_members()) {
                            unowned Json.Node item = obj.get_member(name);
                            switch (name) {
                            case "action":
                                action = item.get_string();
                                break;
                            case "argument":
                                argument = item.get_string();
                                break;
                            }
                        }
                
                        if (action != null) {
                            if (argument == "" || argument == null) {
                                this.metadata.controller.trigger_action(action,
                                    null);
                            } else {
                                this.metadata.controller.trigger_action(action,
                                    argument);
                            }
                            // FIXME: use a sound logic or separate REST path
                            if (action == "movePointer") {
                                root = this.pointer_data();
                            } else {
                                root = this.state_data();
                            }
                        } else {
                            root = this.error_data("Action not defined");
                            msg.status_code = 400;
                        }
                    } else {
                        root = this.error_data("Invalid request");
                        msg.status_code = 400;
                    }
                } catch (Error e) {
                    root = this.error_data(e.message);
                    msg.status_code = 400;
                }
            } else {
                root = this.error_data("Not found");
                msg.status_code = 404;
            }

            if (root != null) {
                Json.Generator generator = new Json.Generator();
                generator.set_root(root);
                string response = generator.to_data(null);

                msg.set_response("application/json", Soup.MemoryUse.COPY,
                    response.data);
            }
        }

        public RestServer(Metadata.Pdf metadata, int port_num) {
            TlsCertificate cert = null;
            if (Options.rest_https) {
                var user_conf_dir = GLib.Environment.get_user_config_dir();
                var cert_fname = Path.build_filename(user_conf_dir, "pdfpc",
                    "cert.pem");
                var key_fname = Path.build_filename(user_conf_dir, "pdfpc",
                    "key.pem");
                try {
                    cert = new TlsCertificate.from_files(cert_fname, key_fname);
                } catch (Error e) {
                    GLib.printerr("Error loading TLS certificate: %s\n",
                        e.message);
                    Process.exit(1);
                }
            }
            Object(tls_certificate: cert);

            this.metadata = metadata;
            if (port_num == 0) {
                port_num = 8088;
            }
            this.port_num = port_num;

            // If defined as an absolute path, use it as is
            if (Options.rest_static_root.has_prefix("/")) {
                this.static_root = Options.rest_static_root;
            } else {
                if (Options.no_install) {
                    this.static_root = Path.build_filename(Paths.SOURCE_PATH,
                        Options.rest_static_root);
                } else {
                    this.static_root = Path.build_filename(Paths.SHARE_PATH,
                        Options.rest_static_root);
                }
            }

            this.add_handler("/api", api_handler);
            this.add_handler("/", static_handler);

            // If the password is not set, generate a random one
            if (Options.rest_passwd == null) {
                Options.rest_passwd = "";
                var r = new Rand();
                int i = 0;
                while (i < 8) {
                    char c = (char) r.int_range(0, 0x7f);
                    if (c.isalnum () == true) {
			Options.rest_passwd.data[i] = c;
                        i++;
		    }
                }
                Options.rest_passwd.data[i] = '\0';
            }

            // Perhaps optionally, the entire "/" path should be protected
            var auth = new Soup.AuthDomainBasic(
                Soup.AUTH_DOMAIN_REALM, "pdfpc REST service",
                Soup.AUTH_DOMAIN_ADD_PATH, "/api");
            auth.set_auth_callback((domain, msg, username, password) => {
                    if (username == "pdfpc" &&
                        password == Options.rest_passwd) {
                        return true;
                    } else {
                        GLib.printerr("Authorization failed: user=%s, pass=%s\n",
                            username, password);
                        return false;
                    }
                });
            auth.set_filter((domain, msg) => {
                    // Don't try to authenticate preflight CORS requests
                    if (msg.method == "OPTIONS") {
                        return false;
                    } else {
                        var path = msg.uri.get_path();
                        // Also, don't authenticate image or html "resources"
                        if (path.has_prefix("/api/slides") ||
                            path.has_prefix("/api/notes")) {
                            return false;
                        } else {
                            return true;
                        }
                    }
                });
            this.add_auth_domain(auth);
        }

        public void start() {
            try {
                var options = 0;
                if (Options.rest_https) {
                    options = Soup.ServerListenOptions.HTTPS;
                }
                this.listen_all(this.port_num, options);
            } catch (Error e) {
                GLib.printerr("Error starting REST server: %s\n", e.message);
                Process.exit(1);
            }
        }

        public string? get_connection_info() {
            string ipaddr4;

            // no truly OS-neutral API to find out the IP(s) we bound to;
            // doing some dirty guess
            try {
                char hostname[256];
                Posix.gethostname(hostname);

                Resolver resolver = Resolver.get_default();

                List<InetAddress> addresses =
                    resolver.lookup_by_name((string) hostname, null);
                InetAddress address4 = addresses.nth_data(0);
                ipaddr4 = address4.to_string();
            } catch (Error e) {
                return null;
            }

            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            builder.set_member_name("address");
            builder.add_string_value(ipaddr4);
            builder.set_member_name("port");
            builder.add_int_value(this.port_num);
            builder.set_member_name("ssl");
            builder.add_boolean_value(this.is_https());
            builder.set_member_name("password");
            builder.add_string_value(Options.rest_passwd);

            builder.end_object();
            Json.Node root = builder.get_root();

            Json.Generator generator = new Json.Generator();
            generator.set_root(root);

            return generator.to_data(null);
        }
    }
}
