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
    }

    public Storage.Base create(Metadata.Pdf metadata) {
        return new Storage.MemoryUncompressed(metadata);
    }
}
