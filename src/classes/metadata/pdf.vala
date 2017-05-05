/**
 * Pdf metadata information
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012, 2015 Robert Schroll
 * Copyright 2012 Pascal Germroth
 * Copyright 2012 David Vilar
 * Copyright 2012, 2015 Andreas Bilke
 * Copyright 2013 Stefan Tauner
 * Copyright 2015 Maurizio Tomasi
 * Copyright 2015 endzone
 * Copyright 2017 Olivier Pantalé
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
     * Metadata for Pdf files
     */
    public class Pdf: Object {
        /**
         * Unique Resource Locator for the given slideset
         */
        protected string url;

        /**
         * Return the registered url
         */
        public string get_url() {
            return this.url;
        }

        public string? pdf_fname = null;
        protected string? pdfpc_fname = null;

        /**
         * Poppler document which belongs to the associated pdf file
         */
        protected Poppler.Document document;

        /**
         * Pdf page width
         */
        protected double original_page_width;

        /**
         * Pdf page height
         */
        protected double original_page_height;

        /**
         * Indicates if pages contains also notes and there position (e. g. when using latex beamer)
         */
        protected NotesPosition notes_position;

        /**
         * Number of pages in the pdf document
         */
        protected uint page_count;

        /**
         * Notes for the slides (text only)
         */
        protected slides_notes notes;

        /**
         * The a virtual mapping of "real pages" to "user-view pages". The
         * indexes in the vector are the user-view slide, the contents are the
         * real slide numbers.
         */
        private int[] user_view_indexes;

        /**
         * The "end slide" defined by the user
         */
        private int end_user_slide = -1;

        /**
         * The "last displayed" defined by the user
         */
        private int last_saved_slide = -1;

        /**
         * Were the skips modified by the user?
         */
        protected bool skips_by_user;

        /**
         * Duration of the presentation
         */
        protected uint duration;

        /**
         * The font size used for notes. -1 if none is
         * specified in pdfpc file.
         */
        private int _font_size = -1;
        public int font_size { get { return _font_size; } set { _font_size = value; } }

        /**
         * Parse the given pdfpc file
         */
        void parse_pdfpc_file(out string? skip_line) {
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
                            // if duration was set via command line
                            // ignore pdfpc file
                            if (Options.duration == uint.MAX) {
                                this.duration = int.parse(section_content);
                            }
                            break;
                        }
                        case "[end_time]": {
                            // command line first
                            if (Options.end_time == null) {
                                Options.end_time = section_content;
                            }
                            break;
                        }
                        case "[end_user_slide]": {
                            this.end_user_slide = int.parse(section_content);
                            break;
                        }
                        case "[file]": {
                            this.pdf_fname = section_content;
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
                            notes.parse_lines(section_content.split("\n"));
                            break;
                        }
                        case "[notes_position]": {
                            // command line first
                            if (Options.notes_position == null) {
                                this.notes_position = NotesPosition.from_string(section_content);
                            }
                            break;
                        }
                        case "[skip]": {
                            skip_line = section_content;
                            skips_by_user = true;
                            break;
                        }
                        case "[start_time]": {
                            // command line first
                            if (Options.start_time == null) {
                                Options.start_time = section_content;
                            }
                            break;
                        }
                        default: {
                            GLib.printerr("unknown section type %s\n", section_type);
                            break;
                        }
                    }
                }
            } catch (Error e) {
                GLib.printerr("%s\n", e.message);
                Process.exit(1);
            }
        }

        /**
         * Parse the line for the skip slides
         */
        void parse_skip_line(string line) {
            int s = 0; // Counter over real slides
            string[] fields = line.split(",");
            for (int f = 0; f < fields.length - 1; ++f) {
                if ( fields[f] == "")
                    continue;
                int current_skip = int.parse(fields[f]) - 1;
                while (s < current_skip) {
                    user_view_indexes += s;
                    ++s;
                }
                ++s;
            }
            // Now we have to reach the end
            while (s < this.page_count) {
                user_view_indexes += s;
                ++s;
            }
        }

        /**
         * Fill the path information starting from the user provided filename
         */
        void fill_path_info(string fname) {
            int l = fname.length;

            if (l < 6 || fname[l-6:l] != ".pdfpc") {
                this.pdf_fname = fname;
                int extension_index = fname.last_index_of(".");
                if (extension_index > -1)
                    this.pdfpc_fname = fname[0:extension_index] + ".pdfpc";
                else
                    this.pdfpc_fname = fname + ".pdfpc";
            } else {
                this.pdfpc_fname = fname;
            }
        }

        /**
         * Called on quit
         */
        public void quit() {
            this.save_to_disk();
            foreach (var mapping in this.action_mapping) {
                mapping.deactivate();
            }
        }

        /**
         * Save the metadata to disk, if needed (i.e. if the user did something
         * with the notes or the skips)
         */
        public void save_to_disk() {
            string contents =   format_command_line_options()
                              + format_skips()
                              + format_end_user_slide()
			      + format_last_saved_slide()
                              + format_font_size()
                              + format_notes();
            try {
                if (contents != "" || GLib.FileUtils.test(this.pdfpc_fname, (GLib.FileTest.IS_REGULAR))) {
                    contents = "[file]\n" + this.pdf_fname + "\n" + contents;
                    GLib.FileUtils.set_contents(this.pdfpc_fname, contents);
                }
            } catch (Error e) {
                GLib.printerr("Failed to store metadata on disk: %s\nThe metadata was:\n\n%s", e.message, contents);
                Process.exit(1);
            }
        }

        /**
         * Format the skip information for saving to disk
         */
        protected string format_skips() {
            string contents = "";
            if (this.user_view_indexes.length <= this.page_count && this.skips_by_user) {
                contents += "[skip]\n";
                int user_slide = 0;
                for (int slide = 0; slide < this.page_count; ++slide) {
                    if (slide != user_view_indexes[user_slide]) {
                        contents += "%d,".printf(slide + 1);
                    } else {
                        ++user_slide;
                    }
                }
                contents += "\n";
            }

            return contents;
        }

        protected string format_end_user_slide() {
            string contents = "";
            if (this.end_user_slide >= 0) {
                contents += "[end_user_slide]\n%d\n".printf(this.end_user_slide);
            }

            return contents;
        }

        protected string format_last_saved_slide() {
            string contents = "";
            if (this.last_saved_slide >= 0) {
                contents += "[last_saved_slide]\n%d\n".printf(this.last_saved_slide);
            }

            return contents;
        }

        protected string format_font_size() {
            string contents = "";
            if (this.font_size >= 0) {
                contents += "[font_size]\n%d\n".printf(this.font_size);
            }

            return contents;
        }

        /**
         * Format the notes for saving to disk
         */
        protected string format_notes() {
            string contents = "";
            if (this.notes.has_notes()) {
                contents += ("[notes]\n" + this.notes.format_to_save());
            }

            return contents;
        }

        protected string format_command_line_options() {
            string contents = "";
            if (this.duration != uint.MAX) {
                contents += "[duration]\n%u\n".printf(duration);
            }
            if (Options.end_time != null) {
                contents += "[end_time]\n%s\n".printf(Options.end_time);
            }
            if (this.notes_position != NotesPosition.NONE) {
                contents += "[notes_position]\n%s\n".printf(this.notes_position.to_string());
            }
            if (Options.last_minutes != 5) {
                contents += "[last_minutes]\n%u\n".printf(Options.last_minutes);
            }
            if (Options.start_time != null) {
                contents += "[start_time]\n%s\n".printf(Options.start_time);
            }

            return contents;
        }

        /**
         * Fill the slide notes from pdf text annotations.
         */
        private void notes_from_document() {
            for(int i = 0; i < this.page_count; i++) {
                var page = this.document.get_page(i);
                List<Poppler.AnnotMapping> anns = page.get_annot_mapping();
                foreach(unowned Poppler.AnnotMapping am in anns) {
                    var a = am.annot;
                    switch(a.get_annot_type()) {
                        case Poppler.AnnotType.TEXT:
                            this.notes.set_note(a.get_contents(), real_slide_to_user_slide(i));
                            break;
                    }
                }
            }
        }

        /**
         * Base constructor taking the file url to the pdf file
         */
        public Pdf(string fname) {
            this.url = File.new_for_commandline_arg(fname).get_uri();

            this.action_mapping = new Gee.ArrayList<ActionMapping>();

            this.notes_position = NotesPosition.from_string(Options.notes_position);

            this.duration = Options.duration;

            fill_path_info(fname);
            notes = new slides_notes();
            skips_by_user = false;
            string? skip_line = null;
            if (GLib.FileUtils.test(this.pdfpc_fname, (GLib.FileTest.IS_REGULAR))) {
                parse_pdfpc_file(out skip_line);
            }
            this.document = this.open_pdf_document(this.pdf_fname);

            // Cache some often used values to minimize thread locking in the
            // future.
            this.page_count = this.document.get_n_pages();
            this.document.get_page(0).get_size(
                out this.original_page_width,
                out this.original_page_height
            );

            if (Options.disable_auto_grouping && !skips_by_user) {
                // Ignore overlayed slides
                for (int i = 0; i < this.page_count; ++i) {
                    this.user_view_indexes += i;
                }
            }

            if (!Options.disable_auto_grouping && !skips_by_user) {
                // Auto-detect which pages to skip
                string previous_label = null;
                for (int i = 0; i < this.page_count; ++i) {
                    string this_label = this.document.get_page(i).label;
                    if (this_label != previous_label) {
                        this.user_view_indexes += i;
                        previous_label = this_label;
                    }
                }
            }

            if(skips_by_user) {
                parse_skip_line(skip_line);
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
            return this.user_view_indexes.length;
        }

        /**
         * Return the last slide defined by the user. It may be different as
         * get_user_slide_count()!
         */
        public int get_end_user_slide() {
            if (this.end_user_slide >= 0)
                return this.end_user_slide;
            else
                return this.get_user_slide_count();
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
         * Toggle the skip flag for one slide
         *
         * We require to be provided also with the user_slide_number, as this
         * info should be available and so we do not need to perform a search.
         *
         * Returns the offset to move the current user_slide_number
         */
        public int toggle_skip(int slide_number, int user_slide_number) {
            if (slide_number == 0) {
                return 0; // We cannot skip the first slide
            }
            skips_by_user = true;
            int converted_user_slide = user_slide_to_real_slide(user_slide_number);
            int offset;
            int l = this.user_view_indexes.length;
            if (converted_user_slide == slide_number) { // Activate skip
                int[] new_indexes = new int[ l-1 ];
                for (int i = 0; i < user_slide_number; ++i) {
                    new_indexes[i] = this.user_view_indexes[i];
                }
                for (int i = user_slide_number + 1; i < l; ++i) {
                    new_indexes[i-1] = this.user_view_indexes[i];
                }
                this.user_view_indexes = new_indexes;
                if (this.end_user_slide >= 0 && user_slide_number < this.end_user_slide) {
                    --this.end_user_slide;
                }
                offset = -1;
            } else { // Deactivate skip
                int[] new_indexes = new int[ l+1 ];
                for (int i = 0; i <= user_slide_number; ++i) {
                    new_indexes[i] = this.user_view_indexes[i];
                }
                new_indexes[user_slide_number+1] = slide_number;
                for (int i = user_slide_number+1; i < l; ++i) {
                    new_indexes[i+1] = this.user_view_indexes[i];
                }
                this.user_view_indexes = new_indexes;
                if (this.end_user_slide >= 0 && user_slide_number < this.end_user_slide) {
                    ++this.end_user_slide;
                }
                offset = +1;
            }

            return offset;
        }

        /**
         * Transform from user slide numbers to real slide numbers
         *
         * If lastSlide is true, the last page of an overlay will be return,
         * otherwise, the first one
         */
        public int user_slide_to_real_slide(int number, bool lastSlide = true) {
            if (lastSlide && number + 1 < user_view_indexes.length) {
                return this.user_view_indexes[number+1] - 1;
            } else if (number < user_view_indexes.length) {
                return this.user_view_indexes[number];
            } else {
                return (int)this.page_count;
            }
        }

        public int real_slide_to_user_slide(int number) {
            // Here we could do a binary search
            int user_slide = 0;
            for (int u = 0; u < this.get_user_slide_count(); ++u) {
                int real_slide = this.user_view_indexes[u];
                if (number == real_slide) {
                    user_slide = u;
                    break;
                } else if (number < real_slide) {
                    user_slide = u - 1;
                    break;
                }
            }

            return user_slide;
        }

        /**
         * Return the width of the first page of the loaded pdf document.
         *
         * If slides contains also notes, this method returns the width of the content part only
         *
         * In presentations all pages will have the same size in most cases,
         * therefore this value is assumed to be useful.
         */
        public double get_page_width() {
            if (    this.notes_position == NotesPosition.LEFT
                 || this.notes_position == NotesPosition.RIGHT) {
                 return this.original_page_width / 2;
            } else {
                return this.original_page_width;
            }
        }

        /**
         * Return the height of the first page of the loaded pdf document.
         *
         * If slides contains also notes, this method returns the height of the content part only
         *
         * In presentations all pages will have the same size in most cases,
         * therefore this value is assumed to be useful.
         */
        public double get_page_height() {
            if (    this.notes_position == NotesPosition.TOP
                 || this.notes_position == NotesPosition.BOTTOM) {
                 return this.original_page_height / 2;
            } else {
                return this.original_page_height;
            }
        }

        /**
         * Return the horizontal offset of the given area on the page
         */
        public double get_horizontal_offset(Area area) {
            switch (area) {
                case Area.CONTENT:
                    switch (this.notes_position) {
                        case NotesPosition.LEFT:
                            return this.original_page_width / 2;
                        default:
                            return 0;
                    }
                case Area.NOTES:
                    switch (this.notes_position) {
                        case NotesPosition.RIGHT:
                            return this.original_page_width / 2;
                        default:
                            return 0;
                    }
                default:
                    return 0;
            }
        }

        /**
         * Return the vertical offset of the given area on the page
         */
        public double get_vertical_offset(Area area) {
            switch (area) {
                case Area.CONTENT:
                    switch (this.notes_position) {
                        case NotesPosition.TOP:
                            return this.original_page_height / 2;
                        default:
                            return 0;
                    }
                case Area.NOTES:
                    switch (this.notes_position) {
                        case NotesPosition.BOTTOM:
                            return this.original_page_height / 2;
                        default:
                            return 0;
                    }
                default:
                    return 0;
            }
        }

        /**
         * Return the Poppler.Document associated with this file
         */
        public Poppler.Document get_document() {
            return this.document;
        }

        /**
         * Return the notes for the presentation
         */
        public slides_notes get_notes() {
            return this.notes;
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
            var file = File.new_for_commandline_arg(fname);

            Poppler.Document document = null;

            try {
                document = new Poppler.Document.from_file(
                    file.get_uri(),
                    null
                );
            } catch(GLib.Error e) {
                GLib.printerr("Unable to open pdf file \"%s\": %s\n",
                              fname, e.message);
                Process.exit(1);
            }

            return document;
        }

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
        public weak PresentationController controller = null;

        /**
         * Return the action mappings (link and annotation mappings) for the
         * specified page.  If that page is different from the previous one,
         * destroy the existing action mappings and create new mappings for
         * the new page.
         */
        public unowned Gee.List<ActionMapping> get_action_mapping(int page_num) {
            if (page_num != this.mapping_page_num) {
                foreach (var mapping in this.action_mapping) {
                    mapping.deactivate();
                }
                this.action_mapping.clear();

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
                // Free the mapping memory; already in lock
                //Poppler.Page.free_link_mapping(link_mappings);

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
                // Free the mapping memory; already in lock
                //Poppler.Page.free_annot_mapping(annot_mappings);

                this.mapping_page_num = page_num;
            }
            return this.action_mapping;
        }
    }

    /**
     * Defines an area on a pdf page
     */
    public enum Area {
        FULL,
        CONTENT,
        NOTES;
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
