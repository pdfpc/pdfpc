/**
 * Config file reader
 *
 * This file is part of pdfpc
 *
 * Copyright 2012 David Vilar
 * Copyright 2015 Robert Schroll
 * Copyright 2015 Andreas Bilke
 * Copyright 2016 Andy Barry
 * Copyright 2016 Joakim Nilsson
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
        public ConfigFileReader() { }

        delegate uint binding2uint(string a);
        private void readBindDef(string name, binding2uint conversor, out uint code, out uint modMask) {
            string[] fields = name.split("+");
            modMask = 0x0;
            code = 0x0;
            if (fields.length == 1) {
                code = conversor(name);
            } else if (fields.length == 2) {
                string modString = fields[0];
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
                            GLib.printerr("Warning: Ignoring unknown modifier '%c'\n", modString[m]);
                            break;
                    }
                }
                code = conversor(fields[1]);
            }
            // 'X' adds keybinding shift+x
            if ('A' <= code && code <= 'Z') { // If uppercase
                modMask |= Gdk.ModifierType.SHIFT_MASK;
            }
            // 'S+x' adds keybinding shift+x
            if ('a' <= code && code <= 'z' && ((modMask | Gdk.ModifierType.SHIFT_MASK) == modMask)) { // If lowercase without shift
                code ^= (1 << 5); // Toggle case
            }
        }

        private void bindKey(string wholeLine, string[] fields) {
            if (fields.length != 3) {
                GLib.printerr("Bad key specification: %s\n", wholeLine);
                return;
            }
            uint modMask = 0;
            uint keycode = 0;
            readBindDef(fields[1], Gdk.keyval_from_name, out keycode, out modMask);
            if (keycode == 0x0) {
                GLib.printerr("Warning: Unknown key: %s\n", fields[1]);
            } else {
                Options.BindTuple bt = new Options.BindTuple();
                bt.type = "bind";
                bt.keyCode = keycode;
                bt.modMask = modMask;
                bt.actionName = fields[2];
                Options.key_bindings.add(bt);
            }
        }

        private void unbindKey(string wholeLine, string[] fields) {
            if (fields.length != 2) {
                GLib.printerr("Bad unbind specification: %s\n", wholeLine);
                return;
            }
            uint modMask = 0;
            uint keycode = 0;
            readBindDef(fields[1], Gdk.keyval_from_name, out keycode, out modMask);
            if (keycode == 0x0) {
                GLib.printerr("Warning: Unknown key: %s\n", fields[1]);
            } else {
                Options.BindTuple bt = new Options.BindTuple();
                bt.type = "unbind";
                bt.keyCode = keycode;
                bt.modMask = modMask;
                Options.key_bindings.add(bt);
            }
        }

        private void unbindKeyAll() {
            Options.BindTuple bt = new Options.BindTuple();
            bt.type = "unbindall";
            Options.key_bindings.add(bt);
        }

        private void bindMouse(string wholeLine, string[] fields) {
            if (fields.length != 3) {
                GLib.printerr("Bad mouse specification: %s\n", wholeLine);
                return;
            }
            uint modMask = 0;
            uint button = 0;
            readBindDef(fields[1], (x) => { return (uint)int.parse(x); }, out button, out modMask);
            if (button == 0x0) {
                GLib.printerr("Warning: Unknown button: %s\n", fields[1]);
            } else {
                Options.BindTuple bt = new Options.BindTuple();
                bt.type = "bind";
                bt.keyCode = button;
                bt.modMask = modMask;
                bt.actionName = fields[2];
                Options.mouse_bindings.add(bt);
            }
        }

        private void unbindMouse(string wholeLine, string[] fields) {
            if (fields.length != 2) {
                GLib.printerr("Bad unmouse specification: %s\n", wholeLine);
                return;
            }
            uint modMask = 0;
            uint button = 0;
            readBindDef(fields[1], (x) => { return (uint)int.parse(x); }, out button, out modMask);
            if (button == 0x0) {
                GLib.printerr("Warning: Unknown button: %s\n", fields[1]);
            } else {
                Options.BindTuple bt = new Options.BindTuple();
                bt.type = "unbind";
                bt.keyCode = button;
                bt.modMask = modMask;
                Options.mouse_bindings.add(bt);
            }
        }

        private void unbindMouseAll() {
            Options.BindTuple bt = new Options.BindTuple();
            bt.type = "unbindall";
            Options.key_bindings.add(bt);
        }


        public void readConfig(string fname) {
            var file = File.new_for_path(fname);
            uint8[] raw_datau8;
            try {
                var splitRegex = new Regex("\\s\\s*");
                var commentRegex = new Regex("\\s*#.*$");
                file.load_contents(null, out raw_datau8, null);
                string[] lines = ((string) raw_datau8).split("\n");
                for (int i=0; i<lines.length; ++i) {
                    string uncommentedLine = commentRegex.replace(lines[i], -1, 0, "");
                    string[] fields = splitRegex.split(uncommentedLine);
                    if (fields.length == 0)
                        continue;
                    switch(fields[0]) {
                        case "bind":
                            this.bindKey(uncommentedLine, fields);
                            break;
                        case "unbind":
                            this.unbindKey(uncommentedLine, fields);
                            break;
                        case "unbind_all":
                            this.unbindKeyAll();
                            break;
                        case "mouse":
                            this.bindMouse(uncommentedLine, fields);
                            break;
                        case "unmouse":
                            this.unbindMouse(uncommentedLine, fields);
                            break;
                        case "unmouse_all":
                            this.unbindMouseAll();
                            break;
                        case "option":
                            this.readOption(uncommentedLine, fields);
                            break;
                        default:
                            GLib.printerr("Warning: Unknown command line \"%s\"\n", uncommentedLine);
                            break;
                    }
                }
            } catch (Error e) {
            }
        }

        private void readOption(string wholeLine, string[] fields) {
            if (fields.length != 3) {
                GLib.printerr("Bad option specification: %s\n", wholeLine);
                return;
            }

            switch (fields[1]) {
                case "black-on-end":
                    Options.black_on_end = bool.parse(fields[2]);
                    break;
                case "current-height":
                    Options.current_height = int.parse(fields[2]);
                    break;
                case "current-size":
                    Options.current_size = int.parse(fields[2]);
                    break;
                case "disable-caching":
                    bool disable_caching = bool.parse(fields[2]);
                    // only propagate value, it it's true
                    // pushing false makes no sense
                    if (disable_caching) {
                        Options.disable_caching = true;
                    }
                    break;
                case "disable-compression":
                    bool disable_compression = bool.parse(fields[2]);
                    // only propagate value, it it's true
                    // pushing false makes no sense
                    if (disable_compression) {
                        Options.disable_cache_compression = true;
                    }
                    break;
                case "next-height":
                    Options.next_height = int.parse(fields[2]);
                    break;
                case "overview-min-size":
                    Options.min_overview_width = int.parse(fields[2]);
                    break;
                case "switch-screens":
                    bool switch_screens = bool.parse(fields[2]);
                    if (switch_screens) {
                        Options.display_switch = true;
                    }
                    break;
                case "time-of-day":
                    bool use_time_of_day = bool.parse(fields[2]);
                    // only propagate value, it it's true
                    // pushing false makes no sense
                    if (use_time_of_day) {
                        Options.use_time_of_day = true;
                    }
                    break;
                default:
                    GLib.printerr("Unknown option %s in pdfpcrc\n", fields[1]);
                    break;
            }
        }
    }
}
