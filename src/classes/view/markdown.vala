/**
 * Markdown View, based on WebKit
 *
 * This file is part of pdfpc.
 *
 * Copyright 2020 Evgeny Stambulchik
 * Inspired by Showdown <https://github.com/showdownjs/showdown>
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

namespace pdfpc.View {
    public class MarkdownView : WebKit.WebView {
        WebKit.UserContentManager ucm;
        
        public MarkdownView() {
            this.ucm = this.get_user_content_manager();

            string css_path;
            if (Options.no_install) {
                css_path = Path.build_filename(Paths.SOURCE_PATH, "rc/notes.css");
            } else {
                css_path = Path.build_filename(Paths.ICON_PATH, "notes.css");
            }

            try {
                File css_file = File.new_for_path(css_path);
                uint8[] css_contents;
                css_file.load_contents(null, out css_contents, null);

                var ss = new WebKit.UserStyleSheet((string) css_contents,
                    WebKit.UserContentInjectedFrames.ALL_FRAMES,
                    WebKit.UserStyleLevel.USER, null, null);
                this.ucm.add_style_sheet(ss);
            } catch (Error e) {
                GLib.printerr("Warning: Could not load CSS %s (%s)\n",
                    css_path, e.message);
            }

            var mdsettings = this.get_settings();
            mdsettings.enable_plugins = false;
            mdsettings.enable_javascript = false;
        }

        // Disable the context menu
        protected override bool context_menu(WebKit.ContextMenu m,
            Gdk.Event e, WebKit.HitTestResult r) {
            return true;
        }

        public void render(string? text = "", bool plain_text = false) {
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

            // Actually render it
            this.load_html(doc, null);
        }

        public void apply_zoom(double level) {
            string css_contents = "body {zoom: %d%%;}".printf((int) (100*level));
            var ss = new WebKit.UserStyleSheet((string) css_contents,
                WebKit.UserContentInjectedFrames.ALL_FRAMES,
                WebKit.UserStyleLevel.USER, null, null);
            this.ucm.add_style_sheet(ss);
        }
    }
}
