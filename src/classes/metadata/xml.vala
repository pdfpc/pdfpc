/**
 * A simple XML parser for XMP metadata in PDF documents
 *
 * Based on <https://wiki.gnome.org/Projects/Vala/MarkupSample>
 *
 * This file is part of pdfpc.
 *
 * Copyright 2017 Evgeny Stambulchik
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
    class XmlParser: Object {

        const MarkupParser parser = {
            start,// when an element opens
            end,  // when an element closes
            text, // when text is found
            null, // when comments are found
            null  // when errors occur
        };

        MarkupParseContext context;

        string text_buffer = null;

        construct {
            context = new MarkupParseContext(parser, 0, this, destroy);

            tags = new Gee.HashMap<string, string> ();
        }

        void destroy() {
        }

        public Gee.HashMap<string, string> parse(string content) throws MarkupError {
            context.parse(content, -1);
            return tags;
        }

        void start(MarkupParseContext context, string name,
                    string[] attr_names, string[] attr_values) throws MarkupError {
            text_buffer = "";
        }

        void end(MarkupParseContext context, string name) throws MarkupError {
            if (name.has_prefix("pdfpc:")) {
                tags.set(name.substring(6), text_buffer);
            }
        }

        void text(MarkupParseContext context,
                   string text, size_t text_len) throws MarkupError {
            if (text_len > 0) {
                text_buffer += text;
            }
        }

        private static Gee.HashMap<string, string> tags;
    }
}
