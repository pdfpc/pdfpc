/**
 * Timer GTK-Label
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

namespace pdfpc {

    /**
      * Factory function for creating TimerLabels, depending if a duration was
      * given.
      */
    TimerLabel getTimerLabel( int duration, time_t end_time, uint last_minutes = 0, time_t start_time = 0 ) {
        if ( end_time > 0 )
            return new EndTimeTimer( end_time, last_minutes, start_time );
        else if ( duration > 0 )
            return new CountdownTimer( duration, last_minutes, start_time );
        else
            return new CountupTimer( start_time );
    }

    /**
     * Specialized label, which is capable of easily displaying a timer
     */
    public abstract class TimerLabel: Gtk.Label {

        /**
         * Time in seconds the presentation has been running. A negative value
         * indicates pretalk mode, if a starting time has been given.
         */
        protected int time = 0;

        /**
         * Start time of the talk to calculate and display a countdown
         */
        protected time_t start_time = 0;

        /**
         * Timeout used to update the timer reqularly
         */
        protected uint timeout = 0;

        /**
         * Default constructor taking the initial time as argument, as well as
         * the time to countdown until the talk actually starts.
         *
         * The second argument is optional. If no countdown_time is specified
         * the countdown will be disabled. The timer is paused in such a case
         * at the given intial_time.
         */
        public TimerLabel( time_t start_time = 0 ) {
            this.start_time = start_time;
        }

        /**
         * Start the timer
         */
        public virtual void start() {
            if ( this.timeout != 0 && this.time < 0 ) {
                // We are in pretalk, with timeout already running.
                // Jump to talk mode
                this.time = 0;
            } else if ( this.timeout == 0 ) {
                // Start the timer if it is not running
                this.timeout = GLib.Timeout.add( 1000, this.on_timeout );
            }
        }

        /**
         * Stop the timer
         */
        public virtual void stop() {
            if ( this.timeout != 0 ) {
                Source.remove( this.timeout );
                this.timeout = 0;
            }
        }

        /**
         * Pauses the timer if it's running. Returns if the timer is paused.
         */
        public bool pause() {
            bool paused = false;
            if ( this.time > 0 ) { // In pretalk mode it doesn't make much sense to pause
                if ( this.timeout != 0 ) {
                    this.stop();
                    paused = true;
                } else {
                    this.start();
                }
            }
            return paused;
        }

        /**
         * Returns if the timer is paused
         */
        public bool is_paused() {
            return (this.time > 0 && this.timeout == 0);
        }

        /**
         * Reset the timer to its initial value
         *
         * Furthermore the stop state will be restored
         * If the countdown is running the countdown value is recalculated. The
         * timer is not stopped in such situation.
         *
         * In presentation mode the time will be reset to the initial
         * presentation time.
         */
        public virtual void reset() {
            this.stop();
            this.time = this.calculate_countdown();
            if ( this.time < 0 )
                this.start();
            else
                this.time = 0;
            this.format_time();
        }

        /**
         * Calculate and return the countdown time in (negative) seconds until
         * the talk begins.
         */
        protected int calculate_countdown()
        {
            time_t now = Time.local( time_t() ).mktime();
            return (int)( now - this.start_time );
        }

        /**
         * Update the timer on every timeout step (every second)
         */
        protected virtual bool on_timeout() {
            ++this.time;
            this.format_time();
            return true;
        }

        /**
         * Shows the corresponding time
         */
        protected abstract void format_time();

        /**
         * Shows a time (in seconds) in hh:mm:ss format, with an additional prefix
         */
        protected void show_time(uint timeInSecs, string prefix) {
            uint hours, minutes, seconds;

            hours = timeInSecs / 60 / 60;
            minutes = timeInSecs / 60 % 60;
            seconds = timeInSecs % 60 % 60;

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

    public class CountdownTimer : TimerLabel {
        /*
         * Duration the timer is reset to if reset is called during
         * presentation mode.
         */
        protected int duration;

        /**
         * Time marker which indicates the last minutes have begun.
         */
        protected uint last_minutes = 5;

        public CountdownTimer( int duration, uint last_minutes, time_t start_time = 0 ) {
            base(start_time);
            this.duration = duration;
            this.last_minutes = last_minutes;
        }

        /**
         * Format the given time in a readable hh:mm:ss way and update the
         * label text
         */
        protected override void format_time() {
            uint timeInSecs;

            // In pretalk mode we display a negative sign before the the time,
            // to indicate that we are actually counting down to the start of
            // the presentation.
            // Normally the default is a positive number. Therefore a negative
            // sign is not needed and the prefix is just an empty string.
            string prefix = "";
            Gtk.StyleContext context = this.get_style_context();
            if ( this.time < 0 ) // pretalk
            {
                prefix = "-";
                timeInSecs = -this.time;
                context.add_class("pretalk");
            } else {
                context.remove_class("pretalk");
                if ( this.time < this.duration ) {
                    timeInSecs = duration - this.time;
                    // Still on presentation time
                    if ( timeInSecs < this.last_minutes * 60 )
                        context.add_class("last-minutes");
                } else {
                    // Time is over!
                    context.remove_class("last-minutes");
                    context.add_class("overtime");
                    timeInSecs = this.time - duration;

                    // The prefix used for negative time values is a simple minus sign.
                    prefix = "-";
                }
            }

            this.show_time(timeInSecs, prefix);
        }
    }

    public class EndTimeTimer : CountdownTimer {

        protected time_t end_time;
        protected Time end_time_object;

        public EndTimeTimer( time_t end_time, uint last_minutes, time_t start_time = 0 ) {
            base(1000, last_minutes, start_time);
            this.end_time = end_time;
            this.end_time_object = Time.local(end_time);
        }

        public override void start() {
            time_t now = Time.local( time_t() ).mktime();
            this.duration = (int)(this.end_time - now);
            base.start();
        }

        public override void stop() {
            base.stop();
            this.set_text(this.end_time_object.format("Until %H:%M"));
        }

        public override void reset() {
            base.reset();
            if ( this.timeout == 0 )
                this.set_text(this.end_time_object.format("Until %H:%M"));
        }

        public override bool on_timeout() {
            if (this.time == -1) { // We will switch from pre-talk to in-talk
                time_t now = Time.local( time_t() ).mktime();
                this.duration = (int)(this.end_time - now);
            }
            return base.on_timeout();
        }
    }

    public class CountupTimer : TimerLabel {
        public CountupTimer( time_t start_time = 0 ) {
            base(start_time);
        }

        /**
         * Format the given time in a readable hh:mm:ss way and update the
         * label text
         */
        protected override void format_time() {
            uint timeInSecs;

            // In pretalk mode we display a negative sign before the the time,
            // to indicate that we are actually counting down to the start of
            // the presentation.
            // Normally the default is a positive number. Therefore a negative
            // sign is not needed and the prefix is just an empty string.
            string prefix = "";
            Gtk.StyleContext context = this.get_style_context();
            if ( this.time < 0 ) // pretalk
            {
                prefix = "-";
                timeInSecs = -this.time;
                context.add_class("pretalk");
            } else {
                timeInSecs = this.time;
                context.remove_class("pretalk");
            }
            this.show_time(timeInSecs, prefix);
        }
    }
}
