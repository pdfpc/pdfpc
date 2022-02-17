/**
 * Action mapping for handling internal links.
 *
 * This file is part of pdfpc.
 *
 * Copyright 2012 Robert Schroll
 * Copyright 2015 Andreas Bilke
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
     * Action for internal links in the PDF file.
     */
    public class LinkAction: ActionMapping {
        /**
         * The Poppler.Action associated with the link.
         */
        public Poppler.Action action;

        /**
         * Base constructor does nothing except assigning the type.
         */
        public LinkAction() {
            this.type = ActionType.LINK;
        }

        /**
         * Initializer.
         */
        public new void init(Poppler.LinkMapping mapping,
            PresentationController controller) {
            base.init(mapping.area, controller);
            this.action = mapping.action.copy();
        }

        /**
         * Find movie on the current slide by its filename; there seems to be
         * no better way with the current Glib Poppler bindings.
         */
        protected ControlledMovie? find_controlled_movie(Poppler.Movie movie) {
            var filename = movie.get_filename();
            if (filename == null) {
                return null;
            }

            var page_num = this.controller.current_slide_number;
            var metadata = this.controller.metadata;
            var mappings = metadata.get_action_mapping(page_num);
            foreach (var mapping in mappings) {
                if (mapping.type == ActionType.MOVIE) {
                    var cmovie = (ControlledMovie) mapping;
                    if (cmovie.filename == filename) {
                        return cmovie;
                    }
                }
            }

            return null;
        }

        /**
         * Create from the LinkMapping if the link is an internal link to a named
         * destination inside the PDF file.
         */
        protected override ActionMapping? new_from_link_mapping(Poppler.LinkMapping mapping,
                PresentationController controller) {
            switch (mapping.action.type) {
            case Poppler.ActionType.URI:
                var new_obj = new LinkAction();
                new_obj.init(mapping, controller);
                return new_obj as ActionMapping;
            case Poppler.ActionType.GOTO_DEST:
                unowned var goto_action = (Poppler.ActionGotoDest*) mapping.action;
                if (goto_action.dest.type == Poppler.DestType.NAMED) {
                    var new_obj = new LinkAction();
                    new_obj.init(mapping, controller);
                    return new_obj as ActionMapping;
                }
                break;
            case Poppler.ActionType.MOVIE:
                unowned var movie_action = (Poppler.ActionMovie*) mapping.action;
                var movie = movie_action.movie;
                if (movie != null) {
                    var new_obj = new LinkAction();
                    new_obj.init(mapping, controller);
                    return new_obj as ActionMapping;
                }
                break;
            default:
                break;
            }

            return null;
        }

        protected override void on_mouse_enter(Gtk.Widget widget, Gdk.EventMotion event) {
            // Set the cursor to the X11 theme default link cursor
            event.window.set_cursor(
                new Gdk.Cursor.from_name(Gdk.Display.get_default(), "hand2")
            );
        }

        /**
         * Launch an application, trying to cover all corner cases.
         */
        private void launch_for_uri(string uri) throws GLib.Error {
            if (Uri.parse_scheme(uri) != null) {
                AppInfo.launch_default_for_uri(uri, null);
            } else {
                // Guess a MIME type and launch its default handler
                bool uncertain;
                var ctype = ContentType.guess(uri, null, out uncertain);
                var appinfo = AppInfo.get_default_for_type(ctype, false);
                string path;
                if (Path.is_absolute(uri)) {
                    path = uri;
                } else {
                    // If the path is not absolute, translate it relative
                    // to the PDF document location
                    var pdf_fname = controller.get_pdf_fname();
                    var dirname = Path.get_dirname(pdf_fname);
                    path = Path.build_filename(dirname, uri);
                }
                var list = new List<File>();
                list.append(File.new_for_path(path));
                appinfo.launch(list, null);
            }
        }

        /**
         * Goto the link's destination on left clicks.
         */
        protected override bool on_button_press(Gtk.Widget widget, Gdk.EventButton event) {
            if (event.button != 1) {
                return false;
            }

            switch (this.action.type) {
            case Poppler.ActionType.URI:
                try {
                    this.launch_for_uri(this.action.uri.uri);
                } catch (GLib.Error e) {
                    GLib.printerr("%s\n", e.message);
                    return true;
                }

                break;
            case Poppler.ActionType.GOTO_DEST:
                unowned var action = (Poppler.ActionGotoDest*) this.action;
                var metadata = this.controller.metadata;

                int slide_number = metadata.find_dest(action.dest);
                this.controller.switch_to_slide_number(slide_number);

                break;
            case Poppler.ActionType.MOVIE:
                unowned var action = (Poppler.ActionMovie*) this.action;
                var movie = action.movie;
                if (movie != null) {
                    var controlled_movie = this.find_controlled_movie(movie);
                    if (controlled_movie != null) {
                        switch (action.operation) {
                        case Poppler.ActionMovieOperation.PAUSE:
                            controlled_movie.pause();
                            break;
                        case Poppler.ActionMovieOperation.PLAY:
                            controlled_movie.rewind();
                            controlled_movie.play();
                            break;
                        case Poppler.ActionMovieOperation.RESUME:
                            controlled_movie.play();
                            break;
                        case Poppler.ActionMovieOperation.STOP:
                            controlled_movie.pause();
                            controlled_movie.rewind();
                            break;
                        }
                    }
                }
                break;
            default:
                return false;
            }

            return true;
        }
    }
}
