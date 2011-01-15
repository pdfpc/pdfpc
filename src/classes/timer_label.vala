/**
 * Timer GTK-Label
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

using Gtk;
using Gdk;

namespace org.westhoffswelt.pdfpresenter {
    /**
     * Specialized label, which is capable of easily displaying a timer
     */
    public class TimerLabel: Gtk.Label {

        /**
         * Time which is currently displayed
         */
        public int time {
            get {
                return this._time;
            }
            set {
                this._time = value;
                this.initial_time = value;
                this.format_time();
            }
        }

        /**
         * Internal storage for currently displayed time
         */
        protected int _time = 0;

        /**
         * Time the timer is reset to if the appropriate function is called
         */
        protected int initial_time;

        /**
         * Timeout used to update the timer reqularly
         */
        protected uint timeout = 0;

        /**
         * Time marker which indicates the last minutes have begun.
         */
        protected uint last_minutes = 5;

        /**
         * Color used for normal timer rendering
         *
         * This property is public and not accesed using a setter to be able to use
         * Color.parse directly on it.
         */
        public Color normal_color;

        /**
         * Color used if last_minutes have been reached
         *
         * This property is public and not accesed using a setter to be able to use
         * Color.parse directly on it.
         */
        public Color last_minutes_color;
        
        /**
         * Color used to represent negative number (time is over)
         *
         * This property is public and not accesed using a setter to be able to use
         * Color.parse directly on it.
         */
        public Color negative_color;

        /**
         * Default constructor taking the initial time as argument
         */
        public TimerLabel( int initial_time ) {
            this.initial_time = initial_time;
            this._time = initial_time;

            // By default the colors are white, yellow and red
            Color.parse( "white", out this.normal_color );
            Color.parse( "orange", out this.last_minutes_color );
            Color.parse( "red", out this.negative_color );
        }

        /**
         * Start the timer
         */
        public void start() {
            if ( this.initial_time != 0 && this.timeout == 0 ) {
                this.timeout = Timeout.add( 1000, this.on_timeout );
            }
        }

        /**
         * Stop the timer
         */
        public void stop() {
            if ( this.timeout != 0 ) {
                Source.remove( this.timeout );
                this.timeout = 0;
            }
        }

        /**
         * Reset the timer to its initial value
         *
         * Furthermore the stop state will be restored
         */
        public void reset() {
            this.stop();
            this._time = this.initial_time;
            this.format_time();
        }

        /**
         * Set the last minute marker
         */
        public void set_last_minutes( uint minutes ) {
            this.last_minutes = minutes;
        }

        /**
         * Update the timer on every timeout step (every second)
         */
        protected bool on_timeout() {
            --this._time;
            this.format_time();
            return true;
        }

        /**
         * Format the given time in a readable hh:mm:ss way and update the
         * label text
         */
        protected void format_time() {
            uint time;
            uint hours, minutes, seconds;

            // The default prefix is an empty string, as the time is normally not
            // negative ;)
            string prefix = "";

            if ( this._time >= 0 ) {
                // Time is positive
                if ( this.initial_time != 0 
                  && this._time < this.last_minutes * 60 ) {
                    this.modify_fg( 
                        StateType.NORMAL, 
                        this.last_minutes_color
                    );
                }
                else {
                    this.modify_fg( 
                        StateType.NORMAL, 
                        this.normal_color
                    );
                }
                
                time = this._time;
            }
            else {
                // We passed the duration therefore time is negative
                this.modify_fg( 
                    StateType.NORMAL, 
                    this.negative_color
                );
                time = this._time * (-1);

                // The prefix used for negative time values is a simple minus sign.
                prefix = "-";
            }

            hours = time / 60 / 60;
            minutes = time / 60 % 60;
            seconds = time % 60 % 60;
            
            this.set_text( 
                "%s%.2u:%.2u:%.2u".printf(
                    prefix,
                    hours,
                    minutes,
                    seconds
                )
            );
        }
    }
}
