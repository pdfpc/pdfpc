/**
 * Storage for the notes of a presentation
 *
 * This file is part of pdf-presenter-console.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
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

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Class for providing storage for the notes associate with a presentation
     */
    public class SlidesNotes: Object {
        /**
         * The array where we will store the text of the notes
         */
        protected string[] notes;

        public void set_note(string note, int slide_number) {
            if (slide_number != -1) {
                if (notes.length <= slide_number)
                    notes.resize(slide_number+1);
                notes[slide_number] = note;
            }
        }

        public string get_note_for_slide(int number) {
            if (number >= notes.length || notes[number] == null)
                return "";
            else
                return notes[number];
        }

        public bool has_notes() {
            return notes.length > 0;
        }

        public SlidesNotes(string? fname) {
            if (fname != null) {
                try {
                    string raw_data;
                    FileUtils.get_contents(fname, out raw_data);
                    string[] lines = raw_data.split("\n");
                    int current_slide = -1;
                    string current_note = "";
                    for (int i=0; i < lines.length; ++i) {
                        if (lines[i][0] == '#') {
                            set_note(current_note, current_slide);
                            current_slide = int.parse(lines[i].substring(1)) - 1;
                            current_note = "";
                        } else {
                            current_note += lines[i] + "\n";
                        }
                    }
                    set_note(current_note, current_slide);
                } catch(GLib.FileError e) {
                    stderr.printf("Could not read notes from file %s\n", fname);
                }
            }
        }
    }
}
