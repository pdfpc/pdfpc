/**
 * Presentation Event controller
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2015 Robert Schroll
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

namespace pdfpc {

    [DBus (name = "io.github.pdfpc")]
    public class DBusServer : Object {

        private string _url;

        public signal void overlay_change(int number);

        public signal void slide_change(int number);

        public int number_of_overlays {
            get {
                return (int) this.metadata.get_slide_count();
            }
        }

        public int number_of_slides {
            get {
                return this.metadata.get_user_slide_count();
            }
        }


        public string url {
            get {
                return _url;
            }
        }

        protected PresentationController controller;
        protected Metadata.Pdf metadata;

        public DBusServer(PresentationController controller, Metadata.Pdf metadata) {
            this.controller = controller;
            this.metadata = metadata;
            this._url = this.metadata.get_url();
            controller.notify["current-slide-number"].connect(
                () => overlay_change(controller.current_slide_number));
            controller.notify["current-user-slide-number"].connect(
                () => slide_change(controller.current_user_slide_number));
        }

        public static void start_server(PresentationController controller, Metadata.Pdf metadata) {
            Bus.own_name(BusType.SESSION, "io.github.pdfpc", BusNameOwnerFlags.NONE,
                (connection) => {
                    try {
                        connection.register_object("/io/github/pdfpc",
                            new DBusServer(controller, metadata));
                    } catch (IOError e) {
                        GLib.printerr("Could not register DBus service.\n");
                    }
                }, () => {}, () => GLib.printerr("Could not acquire DBus bus.\n"));
        }

        public void trigger_action(string name) {
            this.controller.trigger_action(name);
        }

        public string get_notes() {
            return this.metadata.get_notes().get_note_for_slide(controller.current_user_slide_number);
        }
    }
}
