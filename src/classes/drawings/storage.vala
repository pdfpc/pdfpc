/**
 * Classes to handle drawings over slides.
 *
 * This file is part of pdfpc.
 *
 * Copyright 2017 Charles Reiss
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

namespace pdfpc.Drawings.Storage {

    /**
     * Storage of overlay drawings.
     *
     * This is very similar to caching of slide renderings, except we're likely
     * to want to place the overlays in a user-navigible directory and resize
     * them.
     */
    public abstract class Base {
        /**
         * Metadata object to provide drawing storage for
         */
        protected Metadata.Pdf metadata;

        protected Base(Metadata.Pdf metadata) {
            this.metadata = metadata;
        }

        /**
         * Store an overlay drawing with the given index as an identifier.
         */
        public abstract void store(uint index,
                                   DrawingCommandList drawing_commands);
        /**
         * Retrieve an overlay drawing from storage, or null if none was made.
         *
         * The returned reference can be modified without modifying the storage.
         */
        public abstract pdfpc.DrawingCommandList? retrieve(uint index);

        /**
         * Clear the storage
         */
        public abstract void clear();

        /**
         * Does this storage contain any drawing?
         */
        public abstract bool has_any();

        /**
         * Does this storage contain any drawing on this `page`?
         */
        public abstract bool has_any_on(int page);

        /**
         * Export the drawings as a PDF to `path`.
         */
        public abstract void export(string path);

        /**
         * Serialize the drawings on `page`.
         */
        public abstract void serialize(int page, Json.Builder builder);

        /**
         * Deserialize the drawings on `page`.
         */
        public abstract void deserialize(int page, Json.Array content);
    }

    public class MemoryUncompressed : Drawings.Storage.Base {
        /**
         * Actual overlay images.
         */
        protected DrawingCommandList[] drawing_commands_storage = null;

        /**
         * Initialize the storage
         */
        public MemoryUncompressed( Metadata.Pdf metadata ) {
            base(metadata);
            clear();
        }

        public override void store(uint index,
                                   DrawingCommandList drawing_commands) {
            drawing_commands_storage[index] = drawing_commands;
        }

        public override pdfpc.DrawingCommandList? retrieve(uint index) {
            var result = drawing_commands_storage[index];
            drawing_commands_storage[index] = null;
            return result;
        }

        public override void clear() {
            // This is more slots than we might need, but prevents us from being out
            // of bounds if the number of user slides is changed due to overlay marking
            // changing.
            drawing_commands_storage = new pdfpc.DrawingCommandList[this.metadata.get_slide_count()];
        }

        public override bool has_any_on(int page) {
            return this.drawing_commands_storage[page] != null &&
                   this.drawing_commands_storage[page].drawing_commands.length() != 0;
        }

        public override bool has_any() {
            for (int i = 0; i < this.metadata.get_slide_count(); i++) {
                if (this.has_any_on(i)) {
                    return true;
                }
            }
            return false;
        }

        public override void export(string out_file) {
            var surface = new Cairo.PdfSurface(out_file, 0, 0);
            var cr = new Cairo.Context(surface);
    
            surface.set_metadata(Cairo.PdfMetadata.AUTHOR, this.metadata.document.author);
            surface.set_metadata(Cairo.PdfMetadata.CREATE_DATE, this.metadata.document.creation_datetime.to_string());
            surface.set_metadata(Cairo.PdfMetadata.CREATOR, Release.app_name());
            surface.set_metadata(Cairo.PdfMetadata.KEYWORDS, this.metadata.document.keywords);
            surface.set_metadata(Cairo.PdfMetadata.MOD_DATE, new GLib.DateTime.now_local().to_string());
            surface.set_metadata(Cairo.PdfMetadata.SUBJECT, this.metadata.document.subject);
            surface.set_metadata(Cairo.PdfMetadata.TITLE, this.metadata.get_title());
    
            for (int i = 0; i < this.metadata.get_slide_count(); i++) {
                var page = this.metadata.document.get_page(i);
                double width_pt, height_pt;
                page.get_size(out width_pt, out height_pt);
                surface.set_size(width_pt, height_pt);
                page.render_for_printing(cr);

                if (this.has_any_on(i)) {
                    double factor = 2; // what's the correct factor here?
                    int base_width = (int)(width_pt * factor);
                    int base_height = (int)(height_pt * factor);
        
                    double occ_x1, occ_y1, occ_x2, occ_y2;
                    this.drawing_commands_storage[i].occupied_rect(out occ_x1, out occ_y1, out occ_x2, out occ_y2);
                    int width = (int)((occ_x2 - occ_x1) * (double)base_width);
                    int height = (int)((occ_y2 - occ_y1) * (double)base_height);
        
                    Cairo.ImageSurface drawing_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, width, height);
                    {
                        Cairo.Context drawing_cr = new Cairo.Context(drawing_surface);
                        drawing_cr.set_source_rgba(1.0, 1.0, 1.0, 0.0);
                        drawing_cr.rectangle(0, 0, width, height);
                        drawing_cr.fill();
                        drawing_cr.translate(-occ_x1 * (double)base_width, -occ_y1 * (double)base_height);
                        this.drawing_commands_storage[i].paint_on_context(drawing_cr, base_width, base_height);
                    }

                    cr.save();
                    cr.translate(occ_x1 * width_pt, occ_y1 * height_pt);
                    cr.scale(1.0/factor, 1.0/factor);
                    cr.set_source(new Cairo.Pattern.for_surface(drawing_surface));
                    cr.paint();
                    cr.restore();
                }

                cr.show_page();
            }
        }

        public override void serialize(int page, Json.Builder builder) {
            if (this.has_any_on(page)) {
                this.drawing_commands_storage[page].serialize(builder);
            }
        }

        public override void deserialize(int page, Json.Array content) {
            if (content.get_length() == 0) {
                return;
            }
            var l = new DrawingCommandList();
            l.deserialize(content);
            this.drawing_commands_storage[page] = l;
        }
    }

    public Storage.Base create(Metadata.Pdf metadata) {
        return new Storage.MemoryUncompressed(metadata);
    }
}
