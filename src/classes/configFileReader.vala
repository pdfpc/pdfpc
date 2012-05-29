/**
 * Config file reader
 *
 * This file is part of pdfpc
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

namespace pdfpc {
    class ConfigFileReader {
        protected PresentationController presentation_controller;

        public ConfigFileReader(PresentationController controller) {
            this.presentation_controller = controller;
        }

        public void readConfig(string fname) {
            var file = File.new_for_path(fname);
            var splitRegex = new Regex("\\s\\s*");
            uint8[] raw_datau8;
            try {
                file.load_contents(null, out raw_datau8, null);
                string[] lines = ((string) raw_datau8).split("\n");
                for (int i=0; i<lines.length; ++i) {
                    string[] fields = splitRegex.split(lines[i]);
                    if (fields.length == 0 || fields[0][0] == '#')
                        continue;
                    if (fields[0] == "bind") {
                        uint keycode = Gdk.keyval_from_name(fields[1]);
                        this.presentation_controller.bind(keycode, fields[2]);
                    }
                }
            } catch (Error e) {
            }
        }
    }
}
