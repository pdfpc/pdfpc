/**
 * Pdf metadata information
 *
 * This file is part of pdf-presenter-console.
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

using GLib;

namespace org.westhoffswelt.pdfpresenter.Metadata {
    /**
     * Metadata for Pdf files
     */
    public class Pdf: Base
    {
        /**
         * Poppler document which belongs to the associated pdf file
         */
        protected Poppler.Document document;

        /**
         * Pdf page width
         */
        protected double page_width;

        /**
         * Pdf page height
         */
        protected double page_height;

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
        protected int[] user_view_indexes;

        /**
         * Base constructor taking the file url to the pdf file
         */
        public Pdf( string url ) {
            base( url );
        
            this.document = this.open_pdf_document( url );
            
            // Cache some often used values to minimize thread locking in the
            // future.
            MutexLocks.poppler.lock();
            this.page_count = this.document.get_n_pages();
            this.document.get_page( 0 ).get_size( 
                out this.page_width,
                out this.page_height
            );
    
            // Auto-detect which pages to skip
            string previous_label = null;
            this.user_view_indexes.resize((int)this.page_count);
            int user_pages = 0;
            for ( int i = 0; i < this.page_count; ++i ) {
                string this_label = this.document.get_page(i).label;
                if (this_label != previous_label) {
                    this.user_view_indexes[user_pages] = i;
                    previous_label = this_label;
                    ++user_pages;
                }
            }
            this.user_view_indexes.resize(user_pages);
            MutexLocks.poppler.unlock();

            //// Read which slides we have to skip
            //try {
            //     string raw_data;
            //     FileUtils.get_contents("skip", out raw_data);
            //     string[] lines = raw_data.split("\n"); // Note, there is a "ficticious" line at the end
            //     int s = 0; // Counter over real slides
            //     int us = 0; // Counter over user slides
            //     user_view_indexes.resize((int)this.page_count - lines.length + 1);
            //     for ( int l=0; l < lines.length-1; ++l ) {
            //         int current_skip = int.parse( lines[l] ) - 1;
            //         while ( s < current_skip ) {
            //             user_view_indexes[us++] = s;
            //             ++s;
            //         }
            //         ++s;
            //     }
            //     // Now we have to reach the end
            //     while ( s < this.page_count ) {
            //         user_view_indexes[us++] = s;
            //         ++s;
            //     }
            //} catch (GLib.FileError e) {
            //     stderr.printf("Could not read skip information\n");
            //}
            //stdout.printf("user_view_indexes = [");
            //for ( int s=0; s < user_view_indexes.length; ++s)
            //     stdout.printf("%d ", user_view_indexes[s]);
            //stdout.printf("]\n");
        }
    
        public void open_notes( string fname ) {
            notes = new slides_notes(fname);
        }

        /**
         * Return the number of pages in the pdf document
         */
        public override uint get_slide_count() {
            return this.page_count;
        }

        /**
         * Return the number of user slides
         */
        public int get_user_slide_count() {
            return this.user_view_indexes.length;
        }

        /**
         * Transform from user slide numbers to real slide numbers
         */
        public int user_slide_to_real_slide(int number) {
            if ( number < user_view_indexes.length )
                return this.user_view_indexes[number];
            else
                return (int)this.page_count;
        }

        /**
         * Return the width of the first page of the loaded pdf document.
         *
         * In presentations all pages will have the same size in most cases,
         * therefore this value is assumed to be useful.
         */
        public double get_page_width() {
            return this.page_width;
        }

        /**
         * Return the height of the first page of the loaded pdf document.
         *
         * In presentations all pages will have the same size in most cases,
         * therefore this value is assumed to be useful.
         */
        public double get_page_height() {
            return this.page_height;
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
         * Open a given pdf document url and return a Poppler.Document for it.
         */
        protected Poppler.Document open_pdf_document( string url ) {
            var file = File.new_for_uri( url );
            
            Poppler.Document document = null;

            MutexLocks.poppler.lock();
            try {
                document = new Poppler.Document.from_file( 
                    file.get_uri(),
                    null
                );
            }
            catch( GLib.Error e ) {
                error( "Unable to open pdf file: %s", e.message );
            }            
            MutexLocks.poppler.unlock();

            return document;
        }
    }
}
