/**
 * Storage for the notes of a presentation
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
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
     * Class for providing storage for the notes associate with a presentation
     */
    public class slides_notes: Object {
        /**
         * The array where we will store the text of the notes
         */
        protected string?[] notes = null;

        /**
         * Set a note for a given slide
         */
        public void set_note(string note, int slide_number) {
            if (slide_number != -1) {
                if (notes.length <= slide_number) {
                    notes.resize(slide_number+1);
                }
                notes[slide_number] = note;
            }
        }

        /**
         * Return the text of a note
         */
        public string get_note_for_slide(int number) {
            if (number >= notes.length || notes[number] == null) {
                return "";
            } else {
                return notes[number];
            }
        }

        /**
         * Does the user want notes?
         */
        public bool has_notes() {
            return notes != null;
        }

        /**
         * Returns the string that should be written to the pdfpc file
         */
        public string format_to_save() {
            var builder = new GLib.StringBuilder();
            try {
                // match for ether [, ] or #
                var escape_regex = new Regex("[\\[\\]#]");
                for (int i = 0; i < notes.length; ++i) {
                    if (notes[i] != null) {
                        builder.append(@"### $(i+1)\n");
                        // match [,],# and replace it with \[ etc. \0 is the whole match (respectively just [,],#)
                        // escaping escape characters is fun!
                        var escaped_text = escape_regex.replace(notes[i], notes[i].length, 0, "\\\\\\0");
                        builder.append(escaped_text);
                    }
                }
            } catch (RegexError e) {
                // we failed in formatting the notes for disk storage. put a
                // raw dump to stderr.
                for (int i = 0; i < notes.length; ++i) {
                    GLib.print("### %d\n%s\n", i, notes[i]);
                }

                GLib.printerr("Formatting notes for pdfpc file failed.\n");
                Process.exit(1);
            }

            return builder.str;
        }

        /**
         * Parse the notes line of the pdfpc file
         */
        public void parse_lines(string[] lines) {
            string long_line = string.joinv("\n", lines);
            string[] notes_sections = long_line.split("### ");

            try {
                // match [,],# with leading \ in the file. Use
                // regex grouping to get only the [,],# character
                var unescape_regex = new Regex("\\\\([\\[\\]#])");

                for (int notes_section = 0; notes_section < notes_sections.length; ++notes_section) {
                    if (notes_sections[notes_section].length == 0) {
                        continue;
                    }
                    int first_newline = notes_sections[notes_section].index_of("\n");
                    var header_string = notes_sections[notes_section][0:first_newline];
                    var notes = notes_sections[notes_section][first_newline + 1:notes_sections[notes_section].length];
                    var notes_unescaped = unescape_regex.replace(notes, notes.length, 0, "\\1");

                    int slide_number = int.parse(header_string);
                    set_note(notes_unescaped, slide_number - 1);

                }
            } catch (RegexError e) {
                GLib.printerr("Parsing notes file failed.\n");
                Process.exit(1);
            }
        }
    }
}
