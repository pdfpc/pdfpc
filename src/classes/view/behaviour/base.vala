/**
 * Abstract View Behaviour
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

namespace pdfpc.View {
    /**
     * Abstract base every View Behaviour implementation has to extend.
     *
     * A Behaviour is a certain characteristic which is added to an existing
     * View on demand.
     */
    public abstract class Behaviour.Base: Object {
        /**
         * View which is associated with this Behaviour
         *
         * If not stated by the Behaviour.Synchronizable interface Behaviour
         * association is exclusive. One Behaviour may only be associated with
         * one View.
         */
        protected View.Pdf target = null;

        /**
         * Base constructor not taking any arguments
         */
        public Base() {
            // Nothing to do here
        }

        /**
         * Return the associated View object
         *
         * If no View has been associated yet null is returned
         */
        public View.Pdf? get_target() {
            return this.target;
        }

        /**
         * Enfore the fact that a Behaviour may only be associated to one View
         */
        protected void enforce_exclusive_association( View.Pdf target )
            throws Behaviour.AssociationError {
            if ( this.target == target ) {
                // Handle multiple association with the same View by simply
                // ignoring it.
                return;
            }

            if ( this.target != null ) {
                throw new Behaviour.AssociationError.BEHAVIOUR_ALREADY_ASSOCIATED(
                    "A behaviour has been associated with two different Views."
                );
            }

            if ( !this.is_supported( target ) ) {
                throw new Behaviour.AssociationError.VIEW_NOT_SUPPORTED(
                    "The View which should be associated is incompatible to the given Behaviour"
                );
            }
        }

        /**
         * Associate the implementing Behaviour with the given View
         */
        public abstract void associate( View.Pdf target )
            throws Behaviour.AssociationError;

        /**
         * Check wheter the given target is supported by this Behaviour
         *
         * By default every View is supported.
         */
        protected bool is_supported( View.Pdf target ) {
            return true;
        }
    }

    /**
     * Error domain used for association errors
     */
    public errordomain Behaviour.AssociationError {
        BEHAVIOUR_ALREADY_ASSOCIATED,
        VIEW_NOT_SUPPORTED
    }
}
