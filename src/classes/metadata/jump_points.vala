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

namespace pdfpc.Metadata {
    /**
     * Class for providing storage for the notes associate with a presentation
     */
    public class jump_points: Object {
      protected Gee.HashMap<uint, int> points = new Gee.HashMap<unichar, int>();
        /**
         * Returns the string that should be written to the pdfpc file
         */
        public string format_to_save() {
            var builder = new GLib.StringBuilder();
            foreach (Gee.Map.Entry<unichar, int> entry in this.points.entries) {
              string key_name = Gdk.keyval_name(entry.key);
              builder.append(@"$(key_name) = $(entry.value)\n");
            }
            return builder.str;
        }

        public Gee.HashMap<uint, int> get_points() {
          return this.points;
        }

        /**
         * Parse the jump points
         */
        public void parse_lines(string[] lines) {
          for (int i = 0 ; i < lines.length ; i++) {
            string line = lines[i];
            string[] tokens = line.split("=");
            uint key = Gdk.keyval_from_name(tokens[0].strip());
            int slide_no = int.parse(tokens[1]);

            this.points.set(key, slide_no);
          }
        }
    }
}
