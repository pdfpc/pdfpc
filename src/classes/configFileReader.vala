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
            uint supportedModifiers = Gdk.ModifierType.SHIFT_MASK 
                                      | Gdk.ModifierType.CONTROL_MASK
                                      | Gdk.ModifierType.META_MASK
                                    ;
            this.presentation_controller.accepted_key_mods = supportedModifiers;
        }

        private void readKeyDef(string keyName, out uint keycode, out uint modMask) {
            string[] keyFields = keyName.split("+");
            modMask = 0x0;
            keycode = 0x0;
            if (keyFields.length == 1) {
                keycode = Gdk.keyval_from_name(keyName);
            } else if (keyFields.length == 2) {
                string modString = keyFields[0];
                for (int m = 0; m < modString.length; ++m) {
                    switch (modString[m]) {
                        case 'S':
                            modMask |= Gdk.ModifierType.SHIFT_MASK;
                            break;
                        case 'C':
                            modMask |= Gdk.ModifierType.CONTROL_MASK;
                            break;
                        case 'A':
                        case 'M':
                            modMask |= Gdk.ModifierType.META_MASK;
                            break;
                        default:
                            stderr.printf("Warning: Ignoring unknown modifier '%c'\n", modString[m]);
                            break;
                    }
                }
                keycode = Gdk.keyval_from_name(keyFields[1]);
            }
        }

        private void bindKey(string wholeLine, string[] fields) {
            if (fields.length != 3) {
                stderr.printf("Bad key specification: %s\n", wholeLine);
                return;
            }
            uint modMask = 0;
            uint keycode = 0;
            readKeyDef(fields[1], out keycode, out modMask);
            if (keycode == 0x0) {
                stderr.printf("Warning: Unknown key: %s\n", fields[1]);
            } else {
                this.presentation_controller.bind(keycode, modMask, fields[2]);
            }
        }
        
        private void unbindKey(string wholeLine, string[] fields) {
            if (fields.length != 2) {
                stderr.printf("Bad unbind specification: %s\n", wholeLine);
                return;
            }
            uint modMask = 0;
            uint keycode = 0;
            readKeyDef(fields[1], out keycode, out modMask);
            if (keycode == 0x0) {
                stderr.printf("Warning: Unknown key: %s\n", fields[1]);
            } else {
                this.presentation_controller.unbind(keycode, modMask);
            }
        }

        public void readConfig(string fname) {
            var file = File.new_for_path(fname);
            var splitRegex = new Regex("\\s\\s*");
            var commentRegex = new Regex("\\s*#.*$");
            uint8[] raw_datau8;
            try {
                file.load_contents(null, out raw_datau8, null);
                string[] lines = ((string) raw_datau8).split("\n");
                for (int i=0; i<lines.length; ++i) {
                    string uncommentedLine = commentRegex.replace(lines[i], -1, 0, "");
                    string[] fields = splitRegex.split(uncommentedLine);
                    if (fields.length == 0)
                        continue;
                    switch(fields[0]) {
                        case "bind":
                            bindKey(uncommentedLine, fields);
                            break;
                        case "unbind":
                            unbindKey(uncommentedLine, fields);
                            break;
                        case "unbind_all":
                            this.presentation_controller.unbindAll();
                            break;
                        case "switch-screens":
                            Options.display_switch = !Options.display_switch;
                            break;
                        default:
                            stderr.printf("Warning: Unknown command line \"%s\"\n", uncommentedLine);
                            break;
                    }
                }
            } catch (Error e) {
            }
        }
    }
}
