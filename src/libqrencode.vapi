/* qrencode.vapi
 *
 * Copyright (C) 2015 Ignacio Casal Quinteiro
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301 USA
 *
 * As a special exception, if you use inline functions from this file,
 * this file does not by itself cause the resulting executable to be
 * covered by the GNU Lesser General Public License.
 */
namespace Qrencode {
    [CCode (cheader_filename = "qrencode.h", cname = "QRcode", unref_function = "QRcode_free")]
    public class QRcode {
        [CCode (cname = "QRcode_encodeString")]
        public QRcode.encodeString(string digits, int version, EcLevel level, Mode hint, int casesensitive);

        public int version;
        public int width;
        [CCode (array_length = false)]
        public uint8[] data;
    }

    [CCode (cheader_filename = "qrencode.h", cname="QRencLevel")]
    public enum EcLevel {
        [CCode (cname="QR_ECLEVEL_L")]
        L,
        [CCode (cname="QR_ECLEVEL_M")]
        M,
        [CCode (cname="QR_ECLEVEL_Q")]
        Q,
        [CCode (cname="QR_ECLEVEL_H")]
        H
    }

    [CCode (cheader_filename = "qrencode.h", cname="QRencodeMode")]
    public enum Mode {
        [CCode (cname="QR_MODE_NUL")]
        NUL,
        [CCode (cname="QR_MODE_NUM")]
        NUM,
        [CCode (cname="QR_MODE_AN")]
        AN,
        [CCode (cname="QR_MODE_8")]
        B8,
        [CCode (cname="QR_MODE_KANJI")]
        KANJI,
        [CCode (cname="QR_MODE_STRUCTURE")]
        STRUCTURE
    }
}
