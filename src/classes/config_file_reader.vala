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

namespace pdfpc {
    public errordomain ConfigFileError {
        INVALID_BIND
    }

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

        private void bindKeyOrMouse(bool is_mouse,
            string wholeLine, string[] fields) {
            if (fields.length != 3 && fields.length != 4) {
                GLib.printerr("Bad bind specification: %s\n", wholeLine);
                return;
            }
            uint modMask = 0;
            uint keycode = 0;
            Gee.List<Options.BindTuple> bindings;
            if (is_mouse) {
                bindings = Options.mouse_bindings;
                readBindDef(fields[1], (x) => {return (uint)int.parse(x);},
                    out keycode, out modMask);
            } else {
                bindings = Options.key_bindings;
                readBindDef(fields[1], Gdk.keyval_from_name,
                    out keycode, out modMask);
            }
            if (keycode == 0x0) {
                GLib.printerr("Warning: Unknown key/button: %s\n", fields[1]);
            } else {
                try {
                    Options.BindTuple bt = new Options.BindTuple();
                    bt.type = "bind";
                    bt.keyCode = keycode;
                    bt.modMask = modMask;
                    bt.actionName = fields[2];
                    if (fields.length > 3) {
                        bt.setActionArg(fields[3]);
                    }
                    bindings.add(bt);
                } catch (ConfigFileError e) {
                    GLib.printerr("Line '%s' contains errors. Reason: %s\n",
                        wholeLine, e.message);
                }
            }
        }

        private void bindKey(string wholeLine, string[] fields) {
            bindKeyOrMouse(false, wholeLine, fields);
        }

        private void bindMouse(string wholeLine, string[] fields) {
            bindKeyOrMouse(true, wholeLine, fields);
        }

        private void unbindKeyOrMouse(bool is_mouse,
            string wholeLine, string[] fields) {
            if (fields.length != 2) {
                GLib.printerr("Bad unbind specification: %s\n", wholeLine);
                return;
            }
            uint modMask = 0;
            uint keycode = 0;
            Gee.List<Options.BindTuple> bindings;
            if (is_mouse) {
                bindings = Options.mouse_bindings;
                readBindDef(fields[1], (x) => {return (uint)int.parse(x);},
                    out keycode, out modMask);
            } else {
                bindings = Options.key_bindings;
                readBindDef(fields[1], Gdk.keyval_from_name,
                    out keycode, out modMask);
            }
            if (keycode == 0x0) {
                GLib.printerr("Warning: Unknown key/button: %s\n", fields[1]);
            } else {
                Options.BindTuple bt = new Options.BindTuple();
                bt.type = "unbind";
                bt.keyCode = keycode;
                bt.modMask = modMask;
                bindings.add(bt);
            }
        }

        private void unbindKey(string wholeLine, string[] fields) {
            unbindKeyOrMouse(false, wholeLine, fields);
        }

        private void unbindMouse(string wholeLine, string[] fields) {
            unbindKeyOrMouse(true, wholeLine, fields);
        }

        private void unbindKeyAll() {
            Options.BindTuple bt = new Options.BindTuple();
            bt.type = "unbindall";
            Options.key_bindings.add(bt);
        }

        private void unbindMouseAll() {
            Options.BindTuple bt = new Options.BindTuple();
            bt.type = "unbindall";
            Options.mouse_bindings.add(bt);
        }


        public void readConfig(string fname) {
            var file = File.new_for_path(fname);
            try {
                uint8[] raw_datau8;
                file.load_contents(null, out raw_datau8, null);
                string[] lines = ((string) raw_datau8).split("\n");
                for (int i = 0; i < lines.length; ++i) {
                    this.parseStatement(lines[i]);
                }
            } catch (Error e) {
            }
        }

        public void parseStatement(string line) {
            // Strip white spaces
            string statement = line.strip();

            // Ignore comments
            if (statement[0] == '#') {
                return;
            }

            string[] fields = GLib.Regex.split_simple("[ \t]+", statement);

            if (fields.length == 0) {
                return;
            }

            switch(fields[0]) {
            case "bind":
                this.bindKey(statement, fields);
                break;
            case "unbind":
                this.unbindKey(statement, fields);
                break;
            case "unbind_all":
                this.unbindKeyAll();
                break;
            case "mouse":
                this.bindMouse(statement, fields);
                break;
            case "unmouse":
                this.unbindMouse(statement, fields);
                break;
            case "unmouse_all":
                this.unbindMouseAll();
                break;
            case "option":
                this.readOption(statement, fields);
                break;
            default:
                GLib.printerr("Warning: Invalid configuration statement \"%s\"\n",
                    statement);
                break;
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
                case "cache-debug":
                    Options.cache_debug = bool.parse(fields[2]);
                    break;
                case "cache-clean-period":
                    Options.cache_clean_period = int.parse(fields[2]);
                    break;
                case "cache-expiration":
                    Options.cache_expiration = int.parse(fields[2]);
                    break;
                case "cache-max-rtime":
                    Options.cache_max_rtime = int.parse(fields[2]);
                    break;
                case "cache-min-rtime":
                    Options.cache_min_rtime = int.parse(fields[2]);
                    break;
                case "cache-max-usize":
                    Options.cache_max_usize = int.parse(fields[2]);
                    break;
                case "current-height":
                    Options.current_height = int.parse(fields[2]);
                    break;
                case "current-size":
                    Options.current_size = int.parse(fields[2]);
                    break;
                case "cursor-timeout":
                    Options.cursor_timeout = int.parse(fields[2]);
                    break;
                case "disable-input-autodetection":
                    Options.disable_input_autodetection = bool.parse(fields[2]);
                    break;
                case "disable-input-pressure":
                    Options.disable_input_pressure = bool.parse(fields[2]);
                    break;
                case "disable-scrolling":
                    Options.disable_scrolling = bool.parse(fields[2]);
                    break;
                case "disable-tooltips":
                    Options.disable_tooltips = bool.parse(fields[2]);
                    break;
                case "enable-auto-srt-load":
                    Options.auto_srt = bool.parse(fields[2]);
                    break;
                case "final-slide":
                    Options.final_slide_overlay = bool.parse(fields[2]);
                    break;
                case "maximize-in-drawing":
                    Options.maximize_in_drawing = bool.parse(fields[2]);
                    break;
                case "move-on-mapped":
                    Options.move_on_mapped = bool.parse(fields[2]);
                    break;
                case "next-height":
                    Options.next_height = int.parse(fields[2]);
                    break;
                case "next-slide-first-overlay":
                    Options.next_slide_first_overlay = bool.parse(fields[2]);
                    break;
                case "overview-min-size":
                    Options.min_overview_width = int.parse(fields[2]);
                    break;
                case "pointer-color":
                    Options.pointer_color = fields[2];
                    break;
                case "pointer-opacity":
                    Options.pointer_opacity = int.parse(fields[2]);
                    break;
                case "pointer-size":
                    Options.pointer_size = int.parse(fields[2]);
                    break;
                case "prerender-delay":
                    Options.prerender_delay = int.parse(fields[2]);
                    break;
                case "prerender-slides":
                    Options.prerender_slides = int.parse(fields[2]);
                    break;
                case "presentation-interactive":
                    Options.presentation_interactive = bool.parse(fields[2]);
                    break;
                case "presentation-screen":
                    // Don't override command-line setting
                    if (Options.presentation_screen == null) {
                        Options.presentation_screen = fields[2];
                    }
                    break;
                case "presenter-screen":
                    // Don't override command-line setting
                    if (Options.presenter_screen == null) {
                        Options.presenter_screen = fields[2];
                    }
                    break;
#if REST
                case "rest-https":
                    Options.rest_https = bool.parse(fields[2]);
                    break;
                case "rest-port":
                    // don't override command-line setting
                    if (Options.rest_port == 0) {
                        Options.rest_port = int.parse(fields[2]);
                    }
                    break;
                case "rest-passwd":
                    Options.rest_passwd = fields[2];
                    break;
                case "rest-static-root":
                    Options.rest_static_root = fields[2];
                    break;
#endif
                case "spotlight-opacity":
                    Options.spotlight_opacity = int.parse(fields[2]);
                    break;
                case "spotlight-size":
                    Options.spotlight_size = int.parse(fields[2]);
                    break;
                case "status-height":
                    Options.status_height = int.parse(fields[2]);
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
                case "timer-pace-color":
                    bool timer_pace_color = bool.parse(fields[2]);
                    Options.timer_pace_color = timer_pace_color;
                    break;
                case "toolbox":
                    Options.toolbox_shown = bool.parse(fields[2]);
                    break;
                case "toolbox-direction":
                    Options.toolbox_direction =
                        Options.ToolboxDirection.parse(fields[2]);
                    break;
                case "toolbox-minimized":
                    Options.toolbox_minimized = bool.parse(fields[2]);
                    break;
                case "transition-fps":
                    Options.transition_fps = int.parse(fields[2]);
                    break;
                case "windowed-mode":
                    // don't override command-line setting
                    if (Options.windowed == null) {
                        Options.windowed = fields[2];
                    }
                    break;
                default:
                    GLib.printerr("Unknown option %s in pdfpcrc\n", fields[1]);
                    break;
            }
        }
    }
}
