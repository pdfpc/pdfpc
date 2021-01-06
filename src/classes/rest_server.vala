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

        private Json.Node app_data() {
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
            builder.set_member_name("end_slide");
            builder.add_int_value(metadata.get_end_user_slide());
            builder.set_member_name("default_transition");
            builder.add_string_value(Options.default_transition);

            builder.set_member_name("note_is_image");
            builder.add_boolean_value(metadata.has_beamer_notes);

            builder.set_member_name("font_size");
            builder.add_int_value(metadata.get_font_size());

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
            if (controller.running) {
                statestr = "running";
            } else if (controller.is_paused()) {
                statestr = "paused";
            } else {
                statestr = "stopped";
            }
            builder.add_string_value(statestr);

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
            builder.add_string_value("/slides/" + slide_number.to_string() +
                "/image");

            builder.set_member_name("note_url");
            builder.add_string_value("/notes/" + slide_number.to_string());

            builder.end_object();
            return builder.get_root();
        }

        private Json.Node note_data(int slide_number) {
            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            builder.set_member_name("raw_url");
            builder.add_string_value("/notes/" + slide_number.to_string() +
                "/raw");

            builder.set_member_name("html_url");
            builder.add_string_value("/notes/" + slide_number.to_string() +
                "/html");

            builder.end_object();
            return builder.get_root();
        }


        private uint8[]? get_slide_png(int slide_number, int width, int height) {
            try {
                var surface = metadata.renderer.render(slide_number,
                    false, width, height);

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

        private void default_handler(Soup.Server server, Soup.Message msg,
            string path, GLib.HashTable<string, string>? query,
            Soup.ClientContext client) {

            msg.status_code = 200;

            Json.Node root;

            if (path == "/") {
                root = this.app_data();
            } else if (path == "/state") {
                root = this.state_data();
            } else if (path == "/meta") {
                root = this.meta_data();
            } else if (path.has_prefix("/slides/")) {
                try {
                    GLib.Regex regex =
                        new GLib.Regex("/slides/(\\d+)(/image)?");
                    string[] parts = regex.split(path);
                    int nparts = parts.length;

                    int slide_number = 0;
                    if (nparts < 2) {
                        root = this.error_data("Bad request");
                        msg.status_code = 400;
                    } else {
                        slide_number = int.parse(parts[1]);
                        if (nparts == 4) {
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
            } else if (path.has_prefix("/notes/")) {
                try {
                    GLib.Regex regex =
                        new GLib.Regex("/notes/(\\d+)(/html)?");
                    string[] parts = regex.split(path);
                    int nparts = parts.length;

                    int slide_number = 0;
                    if (nparts < 2) {
                        root = this.error_data("Bad request");
                        msg.status_code = 400;
                    } else {
                        slide_number = int.parse(parts[1]);
                        if (nparts == 4) {
                            var note = metadata.get_note(slide_number);
                            var doc = Renderer.MD.render(note,
                                metadata.get_disable_markdown());
                            msg.set_response("text/html",
                                Soup.MemoryUse.COPY, doc.data);
                            return;
                        } else {
                            root = this.note_data(slide_number);
                        }
                    }
                } catch (Error e) {
                    root = this.error_data(e.message);
                    msg.status_code = 500;
                }
            } else if (path == "/control" && msg.method == "PUT") {
                var body = msg.request_body;
                Json.Parser parser = new Json.Parser();
                try {
                    parser.load_from_data((string) body.data,
                        (ssize_t) body.length);
                    Json.Node node = parser.get_root();
                    if (node.get_node_type() == Json.NodeType.OBJECT) {
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
                            if (argument == "") {
                                argument = null;
                            }
                            if (argument == null) {
                                this.metadata.controller.trigger_action(action,
                                    null);
                            } else {
                                this.metadata.controller.trigger_action(action,
                                    argument);
                            }
                            // FIXME: use a sound logic or separate REST path
                            if (action == "pointerMove") {
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

            Json.Generator generator = new Json.Generator();
            generator.set_root(root);
            string response = generator.to_data(null);

            msg.set_response("application/json", Soup.MemoryUse.COPY,
                response.data);
        }

        public RestServer(Metadata.Pdf metadata, int port_num) {
            this.metadata = metadata;
            this.port_num = port_num;

            this.add_handler(null, default_handler);

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
                Soup.AUTH_DOMAIN_ADD_PATH, "/control"
                );
            auth.set_auth_callback((domain, msg, username, password) => {
                    if (username == "pdfpc" &&
                        password == Options.rest_passwd) {
                        return true;
                    } else {
                        printerr("Authorization failed: user=%s, pass=%s\n",
                            username, password);
                        return false;
                    }
                });
            this.add_auth_domain(auth);
        }

        public void start() {
            try {
                this.listen_all(this.port_num, 0);
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
