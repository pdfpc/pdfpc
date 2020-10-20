/**
 * Pdf metadata information
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2012 Pascal Germroth
 * Copyright 2012 David Vilar
 * Copyright 2012, 2015, 2017 Andreas Bilke
 * Copyright 2013 Stefan Tauner
 * Copyright 2015 Maurizio Tomasi
 * Copyright 2015 endzone
 * Copyright 2017 Olivier Pantalé
 * Copyright 2017 Evgeny Stambulchik
 * Copyright 2017 Philipp Berndt
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
    protected class SlideNote {
        public string note_text = null;

        /**
         * Native PDF annotation flag
         */
        public bool is_native = false;
    }

    protected class PageMeta {
        /**
         * PDF page label
         */
        public string label;

        /**
         * User slide #
         */
        public int user_slide;

        /**
         * User slide #
         */
        public bool forced_overlay;

        /**
         * Note
         */
        public SlideNote note;
    }


    public errordomain MetaFileError {
        INVALID_FORMAT
    }

    /**
     * Metadata for PDF files
     */
    public class Pdf: Object {
        public weak PresentationController controller = null;

        /**
         * Renderer to be used for rendering the slides
         */
        public Renderer.Pdf renderer {
            get; protected set;
        }

        public string? pdf_fname {
            get; protected set; default = null;
        }
        protected string? pdfpc_fname = null;

        /**
         * Poppler document of the associated PDF file
         */
        protected Poppler.Document document;

        /**
         * Number of pages in the PDF document
         */
        protected uint page_count;

        /**
         * PDF page dimensions
         */
        protected double original_page_width = 0;
        protected double original_page_height = 0;

        /**
         * Variables used to keep track of the action mappings for the current
         * page.
         */
        private int mapping_page_num = -1;
        private Gee.List<ActionMapping> action_mapping;
        private ActionMapping[] blanks = {
#if MOVIES
            new ControlledMovie(),
#endif
            new LinkAction()
        };

        // BEGIN .pdfpc meta

        /**
         * Per-page meta information
         */
        private Gee.List<PageMeta> pages;

        /**
         * Position of the LaTeX Beamer notes (when present)
         */
        protected NotesPosition notes_position = NotesPosition.NONE;

        /**
         * Assume notes are formatted in Markdown
         */
        public bool enable_markdown { get; protected set; default = true; }

        /**
         * The "end slide" defined by the user
         */
        private int end_user_slide = -1;

        /**
         * The "last displayed" defined by the user
         */
        private int last_saved_slide = -1;

        /**
         * Duration of the presentation
         */
        protected uint duration;

        /**
         * The start/end times of the talk
         */
        public string? start_time { get; protected set; }
        public string? end_time { get; protected set; }

        /**
         * The font size used for notes. -1 if none is
         * specified in pdfpc file.
         */
        public int font_size = -1;

        /**
         * Default page transition
         */
        public Poppler.PageTransition default_transition {
            get; protected set;
        }

        // END .pdfpc meta


        public bool is_ready {
            get {
                return (this.document != null);
            }
        }

        /**
         * Unique Resource Locator for the given slideset
         */
        public string? get_url() {
            if (pdf_fname != null) {
                return File.new_for_commandline_arg(pdf_fname).get_uri();
            } else {
                return null;
            }
        }

        /**
         * Set a note for a given slide (not a user_slide!)
         */
        public void set_note(string note_text, int slide_number,
            bool is_native = false) {

            var page = this.pages.get(slide_number);
            if (page != null) {
                if (page.note == null) {
                    page.note = new SlideNote();
                }
                page.note.note_text = note_text;
                page.note.is_native = is_native;
            }
        }

        /**
         * Return the text of a note
         */
        public string get_note(int slide_number) {
            var page = this.pages.get(slide_number);
            if (page != null && page.note != null) {
                return page.note.note_text;
            } else {
                return "";
            }
        }

        public bool is_note_read_only(int slide_number) {
            var page = this.pages.get(slide_number);
            if (page != null && page.note != null) {
                return page.note.is_native;
            } else {
                return false;
            }
        }

        /**
         * Save the metadata to disk
         */
        public void save_to_disk() {
            Json.Builder builder = new Json.Builder();
            builder.begin_object();

            // Our "magic" header
            builder.set_member_name("pdfpc_format");
            builder.add_int_value(1);

            if (Options.duration > 0) {
                builder.set_member_name("duration");
                builder.add_int_value(Options.duration);
            }
            if (Options.end_time != null) {
                builder.set_member_name("end_time");
                builder.add_string_value(Options.end_time);
            }
            if (Options.start_time != null) {
                builder.set_member_name("start_time");
                builder.add_string_value(Options.start_time);
            }
            if (Options.last_minutes != 5) {
                builder.set_member_name("last_minutes");
                builder.add_int_value(Options.last_minutes);
            }
            if (this.end_user_slide >= 0) {
                builder.set_member_name("end_slide");
                builder.add_int_value(this.end_user_slide);
            }
            if (this.last_saved_slide >= 0) {
                builder.set_member_name("saved_slide");
                builder.add_int_value(this.last_saved_slide);
            }
            if (Options.default_transition != null) {
                builder.set_member_name("default_transition");
                builder.add_string_value(Options.default_transition);
            }

            // Notes
            if (Options.notes_position != null) {
                builder.set_member_name("notes_position");
                builder.add_string_value(this.notes_position.to_string());
            }
            builder.set_member_name("enable_markdown");
            builder.add_boolean_value(this.enable_markdown);
            if (this.font_size > 0) {
                builder.set_member_name("font_size");
                builder.add_int_value(this.font_size);
            }
            builder.set_member_name("pages");
            builder.begin_array();
            int idx = 0, overlay = 0;
            string label = "";
            foreach (var page in this.pages) {
                if (label != page.label) {
                    label = page.label;
                    overlay = 0;
                }
                builder.begin_object();
                builder.set_member_name("idx");
                builder.add_int_value(idx);
                builder.set_member_name("label");
                builder.add_string_value(label);
                builder.set_member_name("overlay");
                builder.add_int_value(overlay);
                if (page.forced_overlay) {
                    builder.set_member_name("forced_overlay");
                    builder.add_boolean_value(true);
                }
                if (page.note != null &&
                    page.note.is_native != true &&
                    page.note.note_text != null) {
                    builder.set_member_name("note");
                    builder.add_string_value(page.note.note_text);
                }
                builder.end_object();
                idx++;
                overlay++;
            }
            builder.end_array();

	    builder.end_object();

	    Json.Generator generator = new Json.Generator();
            Json.Node root = builder.get_root();
	    generator.set_root(root);
	    string contents = generator.to_data(null);

            try {
                if (contents != "") {
                    GLib.FileUtils.set_contents(this.pdfpc_fname, contents);
                }
            } catch (Error e) {
                GLib.printerr("Failed to store metadata on disk: %s\n",
                    e.message);
                GLib.printerr("The metadata was:\n%s\n", contents);
                Process.exit(1);
            }
        }

        private void parse_pdfpc_page(Json.Node node) throws GLib.Error {
	    if (node.get_node_type() != Json.NodeType.OBJECT) {
                throw new MetaFileError.INVALID_FORMAT("Unexpected element type %s",
                    node.type_name());
	    }
	    unowned Json.Object obj = node.get_object();
            string page_label = "", text = "";
            int idx = 0, overlay = 0;
            bool forced_overlay = false;
            foreach (unowned string name in obj.get_members()) {
                unowned Json.Node item = obj.get_member(name);
                switch (name) {
                case "idx":
		    idx = (int) item.get_int();
		    break;
                case "label":
		    page_label = item.get_string();
		    break;
                case "overlay":
		    overlay = (int) item.get_int();
		    break;
                case "forced_overlay":
		    forced_overlay = item.get_boolean();
		    break;
                case "note":
		    text = item.get_string();
		    break;
		default:
                    GLib.printerr("Unknown page item \"%s\"\n", name);
		    break;
		}
	    }

            if (forced_overlay) {
                this.add_overlay(idx);
            }

            if (page_label != "" && text != "") {
                // first, try fast access by index
                var page = this.pages.get(idx);
                if (page != null &&
                    page.label == page_label &&
                    slide_get_overlay(idx) == overlay) {
                    set_note(text, idx);
                } else {
                    int slide_number = -1;
                    for (int i = 0; i < this.page_count; i++) {
                        page = this.pages.get(i);
                        if (page.label == page_label) {
                            slide_number = i + overlay;
                            break;
                        }
                    }
                    page = this.pages.get(slide_number);
                    if (page != null && page.label == page_label) {
                        set_note(text, slide_number);
                    }
                }
            }
        }

        private void parse_pdfpc_pages(Json.Node node) throws GLib.Error {
            if (node.get_node_type () != Json.NodeType.ARRAY) {
                throw new MetaFileError.INVALID_FORMAT("Unexpected element type %s",
                    node.type_name());
            }

            unowned Json.Array array = node.get_array();

            foreach (unowned Json.Node item in array.get_elements()) {
                parse_pdfpc_page(item);
            }
        }

        private void parse_pdfpc_file() throws GLib.Error {
            Json.Parser parser = new Json.Parser();
            try {
                parser.load_from_file(this.pdfpc_fname);
                Json.Node node = parser.get_root();
	        if (node.get_node_type() != Json.NodeType.OBJECT) {
                    throw new MetaFileError.INVALID_FORMAT(
                        "Unexpected element type %s", node.type_name());
	        }

	        unowned Json.Object obj = node.get_object();
                foreach (unowned string name in obj.get_members()) {
                    unowned Json.Node item = obj.get_member(name);
                    switch (name) {
                    case "pdfpc_format":
			int format = (int) item.get_int();
                        // In future, parse depending on the version
                        if (format != 1) {
                            throw new MetaFileError.INVALID_FORMAT(
                                "Unsupported pdfpc format version %d", format);
                        }
			break;
                    case "duration":
			this.duration = (uint) item.get_int();
			break;
                    case "start_time":
			this.start_time = item.get_string();
			break;
                    case "end_time":
			this.end_time = item.get_string();
			break;
                    case "end_slide":
			this.end_user_slide = (int) item.get_int();
			break;
                    case "last_minutes":
			Options.last_minutes = (int) item.get_int();
			break;
                    case "notes_position":
			this.notes_position =
                            NotesPosition.from_string(item.get_string());
			break;
                     case "default_transition":
			this.set_default_transition_from_string(item.get_string());
			break;
                   case "enable_markdown":
			this.enable_markdown = item.get_boolean();
			break;
                   case "font_size":
			this.font_size = (int) item.get_int();
			break;
                   case "pages":
			this.parse_pdfpc_pages(item);
			break;
		    default:
                        GLib.printerr("Unknown item \"%s\"\n", name);
			break;
		    }
	        }

            } catch (GLib.Error e) {
                throw e;
            }
        }

        /**
         * Parse the given pdfpc file, old format
         */
        void parse_pdfpc_file_old(out string? notes_content,
            out string? skip_line) {
            notes_content = null;
            skip_line = null;
            try {
                string content;
                GLib.FileUtils.get_contents(this.pdfpc_fname, out content);
                GLib.Regex regex = new GLib.Regex("(\\[[A-Za-z_]+\\])");


                string[] config_sections = regex.split_full(content);
                // config_sections[0] is empty
                // config_sections[i] = [section_name]
                // config_sections[i + 1] = section_content
                for (int i = 1; i < config_sections.length; i += 2) {
                    string section_type =  config_sections[i].strip();
                    string section_content =  config_sections[i + 1].strip();

                    switch (section_type) {
                        case "[duration]": {
                            set_duration(int.parse(section_content));
                            break;
                        }
                        case "[end_time]": {
                            this.end_time = section_content;
                            break;
                        }
                        case "[end_user_slide]": {
                            set_end_user_slide(int.parse(section_content));
                            break;
                        }
                        case "[font_size]": {
                            this.font_size = int.parse(section_content);
                            break;
                        }
                        case "[last_saved_slide]": {
                            this.last_saved_slide = int.parse(section_content);
                            break;
                        }
                        case "[last_minutes]": {
                            // command line first
                            // 5 is the default value
                            if (Options.last_minutes == 5) {
                                Options.last_minutes = int.parse(section_content);
                            }
                            break;
                        }
                        case "[notes]": {
                            notes_content = section_content;
                            break;
                        }
                        case "[notes_position]": {
                            this.notes_position = NotesPosition.from_string(section_content);
                            break;
                        }
                        case "[skip]": {
                            skip_line = section_content;
                            break;
                        }
                        case "[start_time]": {
                            this.start_time = section_content;
                            break;
                        }
                        default: {
                            GLib.printerr("unknown section type %s\n", section_type);
                            break;
                        }
                    }
                }
                if (skip_line != null) {
                    Options.disable_auto_grouping = true;
                }
            } catch (Error e) {
                GLib.printerr("%s\n", e.message);
                Process.exit(1);
            }
        }


        /**
         * Parse the line for the skip slides, old pdfpc format
         */
        void parse_skip_line_old(string line) {
            string[] fields = line.split(",");
            for (int f = 0; f < fields.length - 1; ++f) {
                if (fields[f] != "") {
                    int current_skip = int.parse(fields[f]) - 1;
                    add_overlay(current_skip);
                }
            }
        }

        /**
         * Parse the notes section of the pdfpc file, old format
         */
        void parse_notes_old(string[] lines) {
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

                    int user_slide = int.parse(header_string) - 1;
                    int slide_number =
                        user_slide_to_real_slide(user_slide, false);
                    // Assign to all slides from the same user slide
                    for (int i = slide_number; i < this.page_count; i++) {
                        var page = this.pages.get(i);
                        if (page.user_slide == user_slide) {
                            set_note(notes_unescaped, i, false);
                        } else {
                            break;
                        }
                    }

                }
            } catch (RegexError e) {
                GLib.printerr("Parsing notes file failed.\n");
                Process.exit(1);
            }
        }

        /**
         * Fill the path information starting from the user provided filename
         */
        void fill_path_info(string fname, string? fpcname = null) {
            if (fpcname != null) {
                this.pdfpc_fname = fpcname;
                this.pdf_fname = fname;
            } else {
                this.pdf_fname = fname;
                int extension_index = fname.last_index_of(".");
                if (extension_index > -1) {
                    this.pdfpc_fname = fname[0:extension_index] + ".pdfpc";
                } else {
                    this.pdfpc_fname = fname + ".pdfpc";
                }
            }
        }

        public void set_default_transition_from_string(string line) {
            var trans = this.default_transition;

            string[] tokens = line.split(":");

            var trans_type = tokens[0];
            switch (trans_type) {
            case "blinds":
                trans.type = Poppler.PageTransitionType.BLINDS;
                break;
            case "box":
                trans.type = Poppler.PageTransitionType.BOX;
                break;
            case "cover":
                trans.type = Poppler.PageTransitionType.COVER;
                break;
            case "dissolve":
                trans.type = Poppler.PageTransitionType.DISSOLVE;
                break;
            case "fade":
                trans.type = Poppler.PageTransitionType.FADE;
                break;
            case "fly":
                trans.type = Poppler.PageTransitionType.FLY;
                break;
            case "glitter":
                trans.type = Poppler.PageTransitionType.GLITTER;
                break;
            case "push":
                trans.type = Poppler.PageTransitionType.PUSH;
                break;
            case "replace":
                trans.type = Poppler.PageTransitionType.REPLACE;
                break;
            case "split":
                trans.type = Poppler.PageTransitionType.SPLIT;
                break;
            case "uncover":
                trans.type = Poppler.PageTransitionType.UNCOVER;
                break;
            case "wipe":
                trans.type = Poppler.PageTransitionType.WIPE;
                break;
            default:
                GLib.printerr("Unknown trans type %s\n", trans_type);
                return;
            }

            if (tokens.length > 1) {
                var trans_duration = double.parse(tokens[1]);
                if (trans_duration > 0) {
                    trans.duration_real = trans_duration;
                } else {
                    GLib.printerr("Transition duration must be positive\n");
                    return;
                }
            }

            if (tokens.length > 2) {
                trans.angle = int.parse(tokens[2]);
            }

            if (tokens.length > 3) {
                var alignment = tokens[3];
                switch (alignment) {
                case "h":
                case "horizontal":
                    trans.alignment =
                        Poppler.PageTransitionAlignment.HORIZONTAL;
                    break;
                case "v":
                case "vertical":
                    trans.alignment =
                        Poppler.PageTransitionAlignment.VERTICAL;
                    break;
                case "":
                    break;
                default:
                    GLib.printerr("Invalid transition alignment %s\n",
                        alignment);
                    return;
                }
            }

            if (tokens.length > 4) {
                var direction = tokens[4];
                switch (direction) {
                case "i":
                case "inward":
                    trans.direction = Poppler.PageTransitionDirection.INWARD;
                    break;
                case "o":
                case "outward":
                    trans.direction = Poppler.PageTransitionDirection.OUTWARD;
                    break;
                case "":
                    break;
                default:
                    GLib.printerr("Invalid transition direction %s\n",
                        direction);
                    return;
                }
            }

            this.default_transition = trans;
        }

        /**
         * Return slide duration
         */
        public double get_slide_duration(int slide_number) {
            if (slide_number >= 0 && slide_number < this.get_slide_count()) {

                var page = this.document.get_page(slide_number);
                return page.get_duration();
            } else {
                return -1;
            }
        }

        /**
         * Deactivate all active mappings
         */
        private void deactivate_mappings() {
            foreach (var mapping in this.action_mapping) {
                mapping.deactivate();
            }
            this.action_mapping.clear();
        }

        /**
         * Called on quit
         */
        public void quit() {
            if (this.is_ready) {
                this.save_to_disk();
            }
            this.deactivate_mappings();
        }

        /**
         * Fill the slide notes from pdf text annotations.
         */
        private void notes_from_document() {
            for (int i = 0; i < this.page_count; i++) {
                var page = this.document.get_page(i);
                string note_text = this.get_note(i);

                // We never overwrite existing notes
                if (note_text != "") {
                    continue;
                }

                List<Poppler.AnnotMapping> anns = page.get_annot_mapping();
                foreach(unowned Poppler.AnnotMapping am in anns) {
                    var a = am.annot;
                    switch (a.get_annot_type()) {
                        case Poppler.AnnotType.TEXT:
                        case Poppler.AnnotType.FREE_TEXT:
                        case Poppler.AnnotType.HIGHLIGHT:
                        case Poppler.AnnotType.UNDERLINE:
                        case Poppler.AnnotType.SQUIGGLY:
                            if (note_text.length > 0) {
                                note_text += "\n";
                            }
                            note_text += a.get_contents();

                            // Remove the annotation to avoid its rendering
                            page.remove_annot(a);

                            break;
                    }
                }
                if (note_text != "") {
                    this.set_note(note_text, i, true);
                }
            }
        }

        /**
         * Parse XMP metadata from the document, if exists
         */
        private void metadata_from_document() {
            string meta = this.document.get_metadata();

            if (meta == null) {
                return;
            }

            XmlParser parser = new XmlParser();
            try {
                var tags = parser.parse(meta);
                foreach (var entry in tags.entries) {
                    switch (entry.key) {
                        case "Duration":
                            set_duration(int.parse(entry.value));
                            break;
                        case "EndUserSlide":
                            set_end_user_slide(int.parse(entry.value));
                            break;
                        case "StartTime":
                            this.start_time = entry.value;
                            break;
                        case "EndTime":
                            this.end_time = entry.value;
                            break;
                        case "LastMinutes":
                            Options.last_minutes = int.parse(entry.value);
                            break;
                        case "NotesPosition":
                            this.notes_position =
                                NotesPosition.from_string(entry.value);
                            break;
                        case "DefaultTransition":
                            this.set_default_transition_from_string(entry.value);
                            break;
                        case "EnableMarkdown":
                            this.enable_markdown = bool.parse(entry.value);
                            break;
                        default:
                            GLib.printerr("unknown XMP entry %s\n", entry.key);
                            break;
                    }
                }
            } catch (Error e) {
                GLib.printerr("XMP parsing error: %s\n", e.message);
            }
        }

        /**
         * Base constructor taking the file url to the pdf file
         */
        public Pdf(string? pdfFilename) {
            this.default_transition = new Poppler.PageTransition();
            this.default_transition.duration_real = 1.0;
            if (pdfFilename != null) {
                this.load(pdfFilename);
            }
            this.renderer = new Renderer.Pdf(this);
        }

        /**
         * Actual file loading, initialization, etc
         */
        public void load(string pdfFilename) {
            var fname = pdfFilename;
            string cwd = GLib.Environment.get_current_dir();
            if (!GLib.Path.is_absolute(fname)) {
                fname = GLib.Path.build_filename(cwd, fname);
            }

            var fpcname = Options.pdfpc_location;
            if (fpcname != null && !GLib.Path.is_absolute(fpcname)) {
                fpcname = GLib.Path.build_filename(cwd, fpcname);
            }
            if (fpcname != null &&
                !GLib.FileUtils.test(fpcname, (GLib.FileTest.IS_REGULAR))) {
                GLib.printerr("Can't find custom pdfpc file at %s\n", fpcname);
                Process.exit(1);
            }

            if (this.action_mapping != null) {
                this.deactivate_mappings();
            } else {
                this.action_mapping = new Gee.ArrayList<ActionMapping>();
            }

            fill_path_info(fname, fpcname);

            this.document = this.open_pdf_document(this.pdf_fname);
            this.page_count = this.document.get_n_pages();
            this.pages = new Gee.ArrayList<PageMeta>();
            for (int i = 0; i < this.page_count; i++) {
                var page = new PageMeta();
                page.user_slide = i;
                page.label = this.document.get_page(i).label;
                this.pages.add(page);
            }

            // Get maximal page dimensions
            for (int i = 0; i < this.page_count; i++) {
                double width1, height1;
                this.document.get_page(i).get_size(out width1, out height1);
                if (this.original_page_width < width1) {
                    this.original_page_width = width1;
                }
                if (this.original_page_height < height1) {
                    this.original_page_height = height1;
                }
            }

            string notes_content_old = null, skip_line_old = null;
            if (GLib.FileUtils.test(this.pdfpc_fname, (GLib.FileTest.IS_REGULAR))) {
                try {
                    parse_pdfpc_file();
                } catch (GLib.Error e) {
                    GLib.printerr("%s\n", e.message);
                    // Try old-style format
                    parse_pdfpc_file_old(out notes_content_old, out skip_line_old);
                }
            }

            // Parse XMP metadata
            this.metadata_from_document();

            // Command line options have the highest priority
            if (Options.duration != 0) {
                set_duration(Options.duration);
            }

            if (Options.start_time != null) {
                this.start_time = Options.start_time;
            }
            if (Options.end_time != null) {
                this.end_time = Options.end_time;
            }
            // If end_time is set, reset duration to 0
            if (this.end_time != null) {
                this.duration = 0;
            }

            if (Options.notes_position != null) {
                this.notes_position =
                    NotesPosition.from_string(Options.notes_position);
            }
            if (this.notes_position != NotesPosition.NONE) {
                Options.disable_auto_grouping = true;
                GLib.printerr("Notes position set, auto grouping disabled.\n");
            }

            if (!Options.disable_auto_grouping) {
                string previous_label = null;
                int user_slide = -1;
                for (int i = 0; i < this.page_count; ++i) {
                    var page = this.pages.get(i);
                    // Auto-detect which pages to skip, but respect overlays
                    // forcefully set by the user
                    string this_label = page.label;
                    if (this_label != previous_label && !page.forced_overlay) {
                        user_slide++;
                        previous_label = this_label;
                    }
                    page.user_slide = user_slide;
                }
            }

            if (notes_content_old != null) {
                this.parse_notes_old(notes_content_old.split("\n"));
                // No Markdown in the old-style pdfpc files
                this.enable_markdown = false;
            }

            if (skip_line_old != null) {
                this.parse_skip_line_old(skip_line_old);
            }

            // Prepopulate notes from annotations
            notes_from_document();
        }

        /**
         * Return the number of pages in the pdf document
         */
        public uint get_slide_count() {
            return this.page_count;
        }

        /**
         * Return the number of user slides
         */
        public int get_user_slide_count() {
            if (this.page_count > 0) {
                var page = this.pages.get((int) this.page_count - 1);
                return page.user_slide + 1;
            } else {
                return 0;
            }
        }

        /**
         * Return the last slide defined by the user. It may be different as
         * get_user_slide_count()!
         */
        public int get_end_user_slide() {
            if (this.end_user_slide >= 0)
                return this.end_user_slide;
            else
                return this.get_user_slide_count() - 1;
        }

        /**
         * Set the last slide defined by the user
         */
        public void set_end_user_slide(int slide) {
            this.end_user_slide = slide;
        }

        /**
         * Return the last displayed slide defined by the user. It may be different as
         * get_user_slide_count()!
         */
        public int get_last_saved_slide() {
            return this.last_saved_slide;
        }

        /**
         * Set the last slide defined by the user
         */
        public void set_last_saved_slide(int slide) {
            this.last_saved_slide = slide;
        }

        /**
         * Add current slide as an overlay
         *
         * Returns the offset to move the current user_slide_number
         */
        public int add_overlay(int slide_number) {
            if (slide_number <= 0) {
                // We cannot skip the first slide
                return 0;
            }
            var prev_page = this.pages.get(slide_number - 1);
            if (prev_page == null) {
                // Something is terribly wrong...
                return 0;
            }
            int prev_user_slide_number = prev_page.user_slide;

            var page = this.pages.get(slide_number);
            if (page == null || page.user_slide == prev_user_slide_number) {
                // Nothing to do
                return 0;
            }
            page.forced_overlay = true;

            for (int i = slide_number; i < this.page_count; i++) {
                page = this.pages.get(i);
                page.user_slide--;
            }
            return -1;
        }

        /**
         * Transform from user slide numbers to real slide numbers
         *
         * If lastSlide is true, the last page of an overlay will be returned,
         * otherwise, the first one
         */
        public int user_slide_to_real_slide(int number, bool lastSlide = true) {
            if (number < 0) {
                return 0;
            } else {
                if (lastSlide) {
                    for (int i = (int)this.page_count - 1; i >= 0; i--) {
                        var page = this.pages.get(i);
                        if (page.user_slide == number) {
                            return i;
                        }
                    }
                } else {
                    for (int i = 0; i < this.page_count; i++) {
                        var page = this.pages.get(i);
                        if (page.user_slide == number) {
                            return i;
                        }
                    }
                }
            }
            return -1;
        }

        /**
         * The user slide corresponding to a real slide.
         *
         * If number is larger than the number of real slides return the
         * last user slide.
         */
        public int real_slide_to_user_slide(int number) {
            if (this.page_count == 0 || number < 0) {
                return -1;
            } else if (number >= this.page_count) {
                return this.get_user_slide_count() - 1;
            } else {
                var page = this.pages.get(number);
                return page.user_slide;
            }
        }

        /**
         * Check whether the given slide is the full user slide (i.e., the
         * last slide within an overlay)
         */
        public bool is_user_slide(int number) {
            int user_slide = real_slide_to_user_slide(number);
            int last_slide = user_slide_to_real_slide(user_slide, true);

            return (number == last_slide);
        }

        /**
         * Get the overlay index of the given slide
         */
        public int slide_get_overlay(int number) {
            int user_slide = real_slide_to_user_slide(number);
            int first_slide = user_slide_to_real_slide(user_slide, false);
            return number - first_slide;
        }

        /**
         * Return the next slide in the overlay (or -1 if doesn't exist),
         * but skipping over slides with automatic advancing
         */
        public int next_in_overlay(int slide_number) {
            if (slide_number < 0 ||
                slide_number >= this.get_slide_count() - 1) {
                return -1;
            } else {
                var next_slide_number = slide_number  + 1;
                while (this.real_slide_to_user_slide(slide_number) ==
                       this.real_slide_to_user_slide(next_slide_number)) {
                    if (this.get_slide_duration(next_slide_number) <= 0) {
                        return next_slide_number;
                    }
                    next_slide_number++;
                }

                return -1;
            }
        }

        /**
         * Return the previous slide in the overlay (or -1 if doesn't exist),
         * but skipping over slides with automatic advancing
         */
        public int prev_in_overlay(int slide_number) {
            if (slide_number < 1 ||
                slide_number >= this.get_slide_count()) {
                return -1;
            } else {
                var prev_slide_number = slide_number - 1;
                while (this.real_slide_to_user_slide(slide_number) ==
                    this.real_slide_to_user_slide(prev_slide_number)) {
                    if (this.get_slide_duration(prev_slide_number) <= 0) {
                        return prev_slide_number;
                    }
                    prev_slide_number--;
                }

                return -1;
            }
        }

        /**
         * Return the width of the first page of the loaded pdf document.
         *
         * If slides also contain notes, return the width of the content part only
         *
         * In presentations all pages will have the same size in most cases,
         * therefore this value is assumed to be useful.
         */
        public double get_page_width() {
            return this.get_corrected_page_width(this.original_page_width);
        }

        /**
         * Fixes the page width if pdfpc uses notes in split mode
         */
        public double get_corrected_page_width(double page_width) {
            if (    this.notes_position == NotesPosition.LEFT
                 || this.notes_position == NotesPosition.RIGHT) {
                 return page_width / 2;
            } else {
                return page_width;
            }
        }

        /**
         * Return the height of the first page of the loaded pdf document.
         *
         * If slides also contain notes, return the height of the content part only
         *
         * In presentations all pages will have the same size in most cases,
         * therefore this value is assumed to be useful.
         */
        public double get_page_height() {
            return this.get_corrected_page_height(this.original_page_height);
        }

        /**
         * Fixes the page height if pdfpc uses notes in split mode
         */
        public double get_corrected_page_height(double page_height) {
            if (    this.notes_position == NotesPosition.TOP
                 || this.notes_position == NotesPosition.BOTTOM) {
                 return page_height / 2;
            } else {
                return page_height;
            }
        }

        /**
         * Return the horizontal offset of the given area on the page
         */
        public double get_horizontal_offset(bool notes_area,
            double page_width = 0) {
            if (page_width == 0) {
                page_width = this.original_page_width;
            }

            if (notes_area) {
                switch (this.notes_position) {
                    case NotesPosition.RIGHT:
                        return page_width / 2;
                    default:
                        return 0;
                }
            } else {
                switch (this.notes_position) {
                    case NotesPosition.LEFT:
                        return page_width / 2;
                    default:
                        return 0;
                }
            }
        }

        /**
         * Return the vertical offset of the given area on the page
         */
        public double get_vertical_offset(bool notes_area,
            double page_height = 0) {
            if (page_height == 0) {
                page_height = this.original_page_height;
            }

            if (notes_area) {
                switch (this.notes_position) {
                    case NotesPosition.BOTTOM:
                        return page_height / 2;
                    default:
                        return 0;
                }
            } else {
                switch (this.notes_position) {
                    case NotesPosition.TOP:
                        return page_height / 2;
                    default:
                        return 0;
                }
            }
        }

        /**
         * Return the Poppler.Document associated with this file
         */
        public Poppler.Document get_document() {
            return this.document;
        }

        /**
         * Return the PDF title
         */
        public string get_title() {
            if (this.document != null) {
                return this.document.get_title();
            } else {
                return "";
            }
        }

        /**
         * Get the duration of the presentation
         */
        public uint get_duration() {
            return this.duration;
        }

        /**
         * Get the duration of the presentation
         */
        public void set_duration(uint d) {
            this.duration = d;
        }

        /**
         * Open a given pdf document url and return a Poppler.Document for it.
         */
        protected Poppler.Document open_pdf_document(string fname) {
            var uri = File.new_for_commandline_arg(fname).get_uri();

            Poppler.Document document = null;

            try {
                document = new Poppler.Document.from_file(uri, null);
            } catch(GLib.Error e) {
                GLib.printerr("Unable to open pdf file \"%s\": %s\n",
                              fname, e.message);
                Process.exit(1);
            }

            return document;
        }

        /**
         * Return the action mappings (link and annotation mappings) for the
         * specified page.  If that page is different from the previous one,
         * destroy the existing action mappings and create new mappings for
         * the new page.
         */
        public unowned Gee.List<ActionMapping> get_action_mapping(int page_num) {
            if (page_num != this.mapping_page_num) {
                this.deactivate_mappings();

                GLib.List<Poppler.LinkMapping> link_mappings;
                link_mappings = this.get_document().get_page(page_num).get_link_mapping();
                foreach (unowned Poppler.LinkMapping mapping in link_mappings) {
                    foreach (var blank in blanks) {
                        var action = blank.new_from_link_mapping(mapping, this.controller, this.document);
                        if (action != null) {
                            this.action_mapping.add(action);
                            break;
                        }
                    }
                }

                GLib.List<Poppler.AnnotMapping> annot_mappings;
                annot_mappings = this.get_document().get_page(page_num).get_annot_mapping();
                foreach (unowned Poppler.AnnotMapping mapping in annot_mappings) {
                    foreach (var blank in blanks) {
                        var action = blank.new_from_annot_mapping(mapping, this.controller, this.document);
                        if (action != null) {
                            this.action_mapping.add(action);
                            break;
                        }
                    }
                }

                this.mapping_page_num = page_num;
            }
            return this.action_mapping;
        }

        public bool has_beamer_notes {
            get {
                return (this.notes_position != NotesPosition.NONE);
            }
        }
    }

    /**
     * Indicates if a pdf has also notes on the pages (and there position)
     */
    public enum NotesPosition {
        NONE,
        TOP,
        BOTTOM,
        RIGHT,
        LEFT;

        public static NotesPosition from_string(string? position) {
            if (position == null) {
                return NONE;
            }

            switch (position.down()) {
                case "left":
                    return LEFT;
                case "right":
                    return RIGHT;
                case "top":
                    return TOP;
                case "bottom":
                    return BOTTOM;
                default:
                    return NONE;
            }
        }

        public string to_string() {
            switch (this) {
                case NONE:
                    return "NONE";
                case TOP:
                    return "TOP";
                case BOTTOM:
                    return "BOTTOM";
                case RIGHT:
                    return "RIGHT";
                case LEFT:
                    return "LEFT";
                default:
                    assert_not_reached();
            }
        }
    }
}
