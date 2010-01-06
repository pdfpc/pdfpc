/**
 * SignalDecorator base class
 *
 * This file is part of pdf-presenter-console.
 *
 * pdf-presenter-console is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3 of the License.
 *
 * pdf-presenter-console is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * pdf-presenter-console; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

using GLib;

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Abstract decorator class to provide additional signals for a given class
     */
    public abstract class SignalDecorator: Object {
        /**
         * First method called on the SignalDecorator after the decoration
         * process started.
         *
         * It is used to ensure object compatability as well as other
         * management stuff. The implementing SignalDecorator is not supposed
         * to override this method. Use a constructor for decorator internal
         * initialization.
         */
        public void initialize( Object target ) {
            if ( !this.is_supported( target ) ) {
                Type decoratable = Type.from_instance( target );
                Type decorator   = Type.from_instance( this );
                error( 
                    "Tried to decorate an object of type '%s' with a signal decorator of type '%s', which is not supported.",
                    decoratable.name(),
                    decorator.name()
                );
            }
        }

        /**
         * The implementation of this method shoudl enable all the needed
         * events needed on the target.
         *
         * Most likely the add_events method with an appropriate event mask
         * will be used for this.
         *
         * No events should be registered in this method use register events
         * for this instead.
         */
        public abstract void enable_events( Object target );

        /**
         * Register all the needed events on the target.
         *
         * Most likely to create some new events/signals you need to handle
         * already existing ones on the target. This is place to register them.
         */
        public abstract void register_events( Object target );
        
        /**
         * Check the given object for comaptibility with this decorator and
         * return a boolean value indicating whether it is compatible or not.
         */
        protected abstract bool is_supported( Object target );
    }
}
