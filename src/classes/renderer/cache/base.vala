/**
 * Cache store
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
 * Copyright 2015 Andreas Bilke
 * Copyright 2015 Robert Schroll
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
     * Base Cache store interface which needs to be implemented by every
     * working cache.
     */
    public abstract class Base : Object {
        /**
         * Metadata object to provide caching for
         */
        protected Metadata.Base metadata;

        /**
         * File name for the file where the persistent cache is stored
         */
        private static string? persist_cache_fname = null;

        /**
         * Common DataInputStream with the persistent cache. This needs to be
         * static to allow all instanciated caches to share one file without
         * having to expose the persistence capabilities to the user.
         */
        private static DataInputStream? cache_input_stream = null;

        /**
         * List of all cache instances for persistent caching; see cache_input_stream.
         *
         * Caches are stored and loaded in the order they are constructed.
         */
        private static List<unowned Base> cache_instances = new List<unowned Base>();

        /**
         * Make all instanciated/active caches persist their data to the
         * on-disk slide cache
         */
        public static void persist_all() {
            if(!cache_update_required) {
                return;
            }

            var cache_file = File.new_for_commandline_arg(persist_cache_fname);

            try {
                var output_stream = new DataOutputStream(cache_file.replace(null, false, FileCreateFlags.NONE));

                foreach(Base element in cache_instances) {
                    element.persist(output_stream);
                }
            }
            catch( Error e ) {
                print( "Failed to persist the cache: %s\n", e.message );

                try { cache_file.delete(); }
                catch( Error e2 ) {}
            }
        }

        /**
         * Flag indicating whether the cache needs to be stored
         */
        protected static bool cache_update_required = true;

        /**
         * Initialize the cache store
         */
        public Base(Metadata.Base metadata) {
            this.metadata = metadata;

            if(Options.persist_cache) {
                if(persist_cache_fname == null) {
                    persist_cache_fname = metadata.get_fname() + "pc_cache";
                }
                if(cache_input_stream == null) {
                    try {
                        var cache_file = File.new_for_commandline_arg(persist_cache_fname);
                        var cache_file_info = cache_file.query_info(FileAttribute.TIME_MODIFIED, 0);
                        var cache_age = cache_file_info.get_modification_time();

                        var pdf_file = File.new_for_commandline_arg(metadata.get_fname());
                        var pdf_file_info = pdf_file.query_info(FileAttribute.TIME_MODIFIED, 0);
                        var pdf_age = pdf_file_info.get_modification_time();

                        if(pdf_age.tv_sec <= cache_age.tv_sec) {
                            cache_input_stream = new DataInputStream(cache_file.read());
                        }
                    }
                    catch( Error e ) { /* Ignore cache errors */ }
                }

                if(cache_input_stream != null) {
                    load_from_disk(cache_input_stream);
                }
                else {
                    cache_update_required = true;
                }
                cache_instances.append(this);
            }
        }

        /**
         * Asks the cache engine if prerendering is allowed in conjunction with it.
         *
         * The default behaviour is to allow prerendering, there might however
         * be engine implementation where prerendering does not make any sense.
         * Therefore it can be disabled by overriding this method and returning
         * false.
         */
        public bool allows_prerendering() {
            return true;
        }

        /**
         * Store a surface in the cache using the given index as identifier
         */
        public abstract void store(uint index, Cairo.ImageSurface surface);

        /**
         * Retrieve a stored surface from the cache.
         *
         * If no item with the given index is available null is returned
         */
        public abstract Cairo.ImageSurface? retrieve(uint index);

        /**
         * Store the cache to disk
         */
        protected abstract void persist(DataOutputStream cache) throws Error;

        /**
         * Load the cache from disk
         */
        protected abstract void load_from_disk(DataInputStream cache) throws Error;
    }

    /**
     * Creates cache engines based on the global commandline options
     */
    public Base create(Metadata.Base metadata) {
        if (!Options.disable_cache_compression)
            return new PNG.Engine(metadata);

        return new Simple.Engine(metadata);
    }
}
