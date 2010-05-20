/**
 * Behaviour Decoratable interface
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

using org.westhoffswelt.pdfpresenter;

namespace org.westhoffswelt.pdfpresenter.View {
    /**
     * Every View which supports Behaviours needs to implement this interface.
     *
     * A Behaviour is a certain characteristic which is added to an existing
     * View on demand.
     */
    public interface Behaviour.Decoratable {
        /**
         * Associate a new Behaviour with this Decoratable
         *
         * The implementation needs to support an arbitrary amount of different
         * behaviours.
         */
        public abstract void associate_behaviour( Behaviour.Base behaviour );
    }
}
