/**
 * PNG cache store
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
 * Copyright 2015 Andreas Bilke
 * Copyright 2016 Phillip Berndt
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

namespace pdfpc.Renderer.Cache {
    /**
     * Cache store which holds all given items in memory as compressed png
     * images and persists the cache on disk
     */
    public class PNG.Persistent.Engine: Renderer.Cache.PNG.Engine {
        private static int cache_instance_counter = 0;

        private int cache_instance_id;
        private int? cache_width = null;
        private int? cache_height = null;
        private GLib.TimeVal? pdf_file_age = null;

        protected string cache_directory;

        public Engine( Metadata.Pdf metadata ) {
            base( metadata );

            cache_instance_counter++;
            cache_instance_id = cache_instance_counter;

            var cache_base_directory = GLib.Environment.get_user_cache_dir();
            this.cache_directory = Path.build_filename(cache_base_directory, "pdfpc");

            try {
                var pdf_file = File.new_for_uri(metadata.get_url());
                var pdf_file_info = pdf_file.query_info(FileAttribute.TIME_MODIFIED, 0);
                pdf_file_age = pdf_file_info.get_modification_time();
            } catch (GLib.Error e) {
                GLib.printerr("Cannot query pdf file modification date\n");
                Process.exit(1);
            }
        }

        protected string get_cache_filename(uint index) {
            if (cache_width == null || cache_height == null) {
                GLib.printerr("This method cannot be called before the size of the images in the cache is known.\n");
                Process.exit(1);
            }

            var file_name = GLib.Checksum.compute_for_string(GLib.ChecksumType.SHA1,
                    metadata.get_url() + "\0" +
                    cache_instance_id.to_string() + "\0" +
                    cache_width.to_string() + "\0" +
                    cache_height.to_string() + "\0" +
                    index.to_string());

            return Path.build_filename(cache_directory, file_name.substring(0, 2), file_name.substring(2) + ".png");
        }

        public override void store(uint index, Cairo.ImageSurface surface) {
            png_store(index, surface);

            if (cache_width == null) {
                cache_width  = surface.get_width();
                cache_height = surface.get_height();
            }

            var cache_file_name = get_cache_filename(index);
            var cache_file = GLib.File.new_for_path(cache_file_name);
            try {
                var parent_directory = cache_file.get_parent();
                if (!parent_directory.query_exists()) {
                    parent_directory.make_directory_with_parents();
                }
                cache_file.replace_contents(storage[index].get_png_data(), null, false, FileCreateFlags.NONE, null);
            } catch(Error e) {
                GLib.printerr("Storing slide %u to cache in %s failed.\n", index, cache_file_name);
                Process.exit(1);
            }
        }

        public override Cairo.ImageSurface? retrieve( uint index ) {
            var item = png_retrieve(index);
            if ( item != null ) {
                return item;
            }

            if (cache_width == null || cache_height == null) {
                return null;
            }

            var cache_candidate = GLib.File.new_for_path(get_cache_filename(index));
            if (cache_candidate.query_exists()) {
                try {
                    var cache_file_info = cache_candidate.query_info(FileAttribute.TIME_MODIFIED + ",standard::size", 0);
                    var cache_age = cache_file_info.get_modification_time();

                    if (pdf_file_age.tv_sec <= cache_age.tv_sec) {
                        uint8[] data = new uint8[cache_file_info.get_size()];
                        cache_candidate.read().read_all(data, null);

                        var cache_item = new PNG.Item(data);
                        storage[index] = cache_item;

                        return png_retrieve(index);
                    }
                } catch(Error e) {
                    /* Fail silently. We cannot fix anything here anyway, and
                       pdfpc will continue to work as expected. */
                }
            }

            return null;
        }
    }
}
