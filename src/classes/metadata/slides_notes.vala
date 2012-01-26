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
    public class slides_notes: Object {
        /**
         * The array where we will store the text of the notes
         */
        protected string?[] notes;

        /**
         * File name for notes
         */
        protected string? fname = null;

        /**
         * Set a note for a given slide
         */
        public void set_note( string note, int slide_number ) {
            if (slide_number != -1) {
                if (notes.length <= slide_number)
                    notes.resize(slide_number+1);
                notes[slide_number] = note;
            }
        }

        /**
         * Return the text of a note
         */
        public string get_note_for_slide( int number ) {
            if (number >= notes.length || notes[number] == null)
                return "";
            else
                return notes[number];
        }

        /**
         * Does the user want notes?
         */
        public bool has_notes() {
            return fname != null;
        }

        /**
         * Save the notes to the filename given in the constructor
         */
        public void save_to_disk() {
            if (fname != null) {
                try {
                    string text="";
                    for (int i = 0; i < notes.length; ++i) {
                        if (notes[i] != null) {
                            text += @"### $(i+1)\n" + notes[i];
                            if (text[text.length-1] != '\n') // [last] == '\0'
                                text += "\n";
                        }
                    }
                    FileUtils.set_contents(fname, text.substring(0, text.length-1));
                } catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
            }
        }

        public slides_notes( string? filename ) {
            if (filename != null) {
                fname = filename;
                try {
                    string raw_data;
                    FileUtils.get_contents(fname, out raw_data);
                    string[] lines = raw_data.split("\n");
                    int current_slide = -1;
                    string current_note = "";
                    for (int i=0; i < lines.length; ++i) {
                        if (lines[i].length > 3 && lines[i][0:3] == "###") {
                            set_note(current_note, current_slide);
                            current_slide = int.parse(lines[i].substring(3)) - 1;
                            current_note = "";
                        } else {
                            current_note += lines[i] + "\n";
                        }
                    }
                    set_note(current_note, current_slide);
                } catch(GLib.FileError e) {
                    if (e is FileError.NOENT) // If file doesn't exits this is no problem
                        stdout.printf("Creating new file %s for notes\n", fname);
                    else
                        stderr.printf("Could not read notes from file %s\n", fname);
                }
            }
        }
    }
}
