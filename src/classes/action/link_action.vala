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
    /**
     * Action for internal links in the PDF file.
     */
    public class LinkAction: ActionMapping {
        /**
         * The Poppler.Action associated with the link.
         */
        public Poppler.Action action;

        /**
         * Base constructor does nothing.
         */
        public LinkAction() {
            base();
        }

        /**
         * Initializer.
         */
        public new void init(Poppler.LinkMapping mapping, PresentationController controller,
                Poppler.Document document) {
            base.init(mapping.area, controller, document);
            this.action = mapping.action.copy();
        }

        /**
         * Create from the LinkMapping if the link is an internal link to a named
         * destination inside the PDF file.
         */
        public override ActionMapping? new_from_link_mapping(Poppler.LinkMapping mapping,
                PresentationController controller, Poppler.Document document) {
            if (   (mapping.action.type != Poppler.ActionType.GOTO_DEST || ((Poppler.ActionGotoDest*)mapping.action).dest.type != Poppler.DestType.NAMED)
                && mapping.action.type != Poppler.ActionType.URI) {
                return null;
            }

            var new_obj = new LinkAction();
            new_obj.init(mapping, controller, document);
            return new_obj as ActionMapping;
        }

        /**
         * Goto the link's destination on left clicks.
         */
        public override bool on_button_press(Gtk.Widget widget, Gdk.EventButton event) {
            if (event.button != 1)
                return false;

            switch (this.action.type) {
                case Poppler.ActionType.URI:
                    try {
                        AppInfo.launch_default_for_uri(this.action.uri.uri, null);
                    } catch (GLib.Error e) {
                        GLib.printerr("%s\n", e.message);

                        return false;
                    }

                    break;
                case Poppler.ActionType.GOTO_DEST:
                    unowned Poppler.ActionGotoDest* action = (Poppler.ActionGotoDest*)this.action;
                    Poppler.Dest destination;
                    destination = this.document.find_dest(action.dest.named_dest);

                    this.controller.page_change_request((int)(destination.page_num - 1));

                    break;
                default:
                    return false;
            }

            return true;
        }
    }
}
