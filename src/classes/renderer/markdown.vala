/**
 * Markdown renderer
 *
 * This file is part of pdfpc.
 *
 * Copyright 2020 Evgeny Stambulchik
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
    public class MD {
        public static string render(string? text = "", bool plain_text = false) {
            Markdown.DocumentFlags flags = Markdown.DocumentFlags.NO_EXT;

            string html;
            if (text != "" && plain_text) {
                html = "<pre>%s</pre>".printf(text.replace("&", "&amp;")
                                                  .replace("<", "&lt;")
                                                  .replace(">", "&gt;"));
            } else {
                var md = new Markdown.Document.from_string(text.data, flags);
                md.compile(flags);

                md.document(out html);
            }

            // Form a minimal compliant Unicode HTML document
            const string tmpl =
                "<!doctype html>\n<html>\n"              +
                "<head><meta charset='utf-8'></head>\n" +
                "<body>\n%s\n</body>\n</html>\n";
            var doc = tmpl.printf(html);

            return doc;
        }
    }
}
