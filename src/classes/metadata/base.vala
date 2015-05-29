/**
 * Slide metadata information
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
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
    /**
     * Metadata base class describing the basic metadata needed for every
     * slideset
     */
    public abstract class Metadata.Base: Object
    {
        /**
          * Filename given in the command line
          */
        protected string fname;

        /**
         * Unique Resource Locator for the given slideset
         */
        protected string url;

        /**
         * Base constructor taking the url to specifiy the slideset as argument
         */
        public Base( string fname ) {
            this.fname = fname;
            this.url = File.new_for_commandline_arg(fname).get_uri();
        }

        /**
         * Return the registered url
         */
        public string get_url() {
            return this.url;
        }

        /**
         * Return the number of slides defined by the given url
         */
        public abstract uint get_slide_count();
    }
}
