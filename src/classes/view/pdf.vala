/**
 * Spezialized Pdf View
 *
 * This file is part of pdfpc.
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
using Gdk;

namespace pdfpc {
    /**
     * View spezialized to work with Pdf renderers.
     *
     * This class is mainly needed to be decorated with pdf-link-interactions
     * signals.
     *
     * By default it does not implement any further functionality.
     */
    public class View.Pdf: View.Default {
        /**
         * Default constructor restricted to Pdf renderers as input parameter
         */
        public Pdf( Renderer.Pdf renderer, bool allow_black_on_end, PresentationController presentation_controller ) {
            base( renderer );

            // Enable the PDFLink Behaviour by default on PDF Views
            this.associate_behaviour( 
                new View.Behaviour.PdfLink.Implementation( presentation_controller )
            );
        }

        /**
         * Create a new Pdf view directly from a file
         *
         * This is a convenience constructor which automatically create a full
         * metadata and rendering chain to be used with the pdf view. The given
         * width and height is used in conjunction with a scaler to maintain
         * aspect ration. The scale rectangle is provided in the scale_rect
         * argument.
         */
        public static View.Pdf from_metadata( Metadata.Pdf metadata, int width, int height, bool allow_black_on_end,
                                              PresentationController presentation_controller,
                                              out Rectangle scale_rect = null ) {
            var scaler = new Scaler( 
                metadata.get_page_width(),
                metadata.get_page_height()
            );
            scale_rect = scaler.scale_to( width, height );
            var renderer = new Renderer.Pdf( 
                metadata,
                scale_rect.width,
                scale_rect.height
            );
            
            return new View.Pdf( renderer, allow_black_on_end, presentation_controller );
        }

        /**
         * Return the currently used Pdf renderer
         */
        public new Renderer.Pdf get_renderer() {
            return this.renderer as Renderer.Pdf;
        }
    }
}
