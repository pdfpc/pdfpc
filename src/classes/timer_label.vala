/**
 * Timer GTK-Label
 *
 * This file is part of pdfpc.
 *
 * Copyright (C) 2010-2011 Jakob Westhoff <jakob@westhoffswelt.de>
 * Copyright 2012 David Vilar
 * Copyright 2013 Michal Sojka
 * Copyright 2015 Andreas Bilke
 * Copyright 2015 Robert Schroll
 * Copyright 2015-2016 Andy Barry
 * Copyright 2017 Evgeny Stambulchik
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
     * Parse the given time string to a Time object
     */
    time_t parseTime(string t) {
        var tm = Time.local(time_t());
        tm.strptime(t + ":00", "%H:%M:%S");
        return tm.mktime();
    }

    /**
      * Factory function for creating TimerLabels, depending if a duration was
      * given.
      */
    TimerLabel getTimerLabel(PresentationController controller, int duration,
        string? start_time_str, string? end_time_str) {

        uint last_minutes = Options.last_minutes;

        // Calculate the countdown to display until the presentation has to
        // start
        time_t start_time = 0;
        if (start_time_str != null) {
            start_time = parseTime(start_time_str);
        }
        // The same again for end_time
        time_t end_time = 0;
        if (end_time_str != null) {
            end_time = parseTime(end_time_str);
        }

        if (Options.use_time_of_day) {
            return new TimeOfDayTimer(controller);
        } else if (end_time > 0) {
            return new EndTimeTimer(controller, end_time, -last_minutes, start_time);
        } else if (duration > 0) {
            return new CountdownTimer(controller, duration, last_minutes, start_time);
        } else {
            return new CountupTimer(controller, start_time);
        }
    }

    /**
     * Specialized label, which is capable of easily displaying a timer
     */
    public abstract class TimerLabel: Gtk.Label {

        protected PresentationController controller;

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
         */
        protected TimerLabel(PresentationController controller, time_t start_time = 0) {
            this.controller = controller;
            this.start_time = start_time;
        }

        /**
         * Start the timer
         */
        public virtual void start() {
            if (this.timeout != 0 && this.time < 0) {
                // We are in pretalk, with timeout already running.
                // Jump to talk mode
                this.start_time = GLib.Time.local(time_t()).mktime(); // now
            } else if (this.timeout == 0) {
                // Start the timer if it is not running
                this.start_time = GLib.Time.local(time_t() - this.time).mktime();
                this.timeout = GLib.Timeout.add(1000, this.on_timeout);
            }
            this.update_time();
        }

        /**
         * Stop the timer
         */
        public virtual void stop() {
            if (this.timeout != 0) {
                Source.remove(this.timeout);
                this.timeout = 0;
            }
        }

        /**
         * Pauses the timer if it's running. Returns if the timer is paused.
         */
        public virtual bool pause() {
            bool paused = false;
            if (this.time > 0) { // In pretalk mode it doesn't make much sense to pause
                if (this.timeout != 0) {
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
        public virtual bool is_paused() {
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
            this.update_time();
            if (this.time < 0) {
                this.start();
            } else {
                this.time = 0;
            }
            this.format_time();
        }

        /**
         * Set the time field to the difference in seconds between now and start_time
         *
         * Time can be negative if the talk begins in future.
         */
        protected virtual void update_time() {
            time_t now = GLib.Time.local(time_t()).mktime();
            this.time =  (int)(now - this.start_time);
        }

        /**
         * Update the timer on every timeout step (every second)
         */
        protected virtual bool on_timeout() {
            update_time();
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
        protected virtual void show_time(uint timeInSecs, string prefix) {
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

        public CountdownTimer(PresentationController controller, int duration, uint last_minutes, time_t start_time = 0) {
            base(controller, start_time);
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
            if (this.time < 0) { // pretalk
                prefix = "-";
                timeInSecs = -this.time;
                context.add_class("pretalk");
            } else {
                context.remove_class("pretalk");
                context.remove_class("last-minutes");
                context.remove_class("overtime");
                context.remove_class("too-slow");
                context.remove_class("too-fast");
                if (this.time < this.duration) {
                    timeInSecs = duration - this.time;
                    // Still on presentation time
                    if (Options.timer_pace_color) {
                        // New indication of too slow/fast pace independently
                        // of the time left.
                        var metadata = this.controller.metadata;
                        int current_slide_number =
                            this.controller.current_user_slide_number;
                        int slide_count = metadata.get_end_user_slide();

                        // Assuming we're in the middle of the current slide
                        double expected_progress =
                            (current_slide_number + 0.5)/slide_count;

                        int expected_time = (int) (duration*expected_progress);

                        if (this.time > expected_time + 60) {
                            context.add_class("too-slow");
                        } else if (this.time < expected_time - 60) {
                            context.add_class("too-fast");
                        } else {
                            context.remove_class("too-fast");
                            context.remove_class("too-slow");
                        }
                    } else {
                        // Old "last-minutes" warning
                        if (timeInSecs < this.last_minutes * 60)
                            context.add_class("last-minutes");
                    }
                } else {
                    // Time is over!
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
        protected GLib.Time end_time_object;

        public EndTimeTimer(PresentationController controller, time_t end_time, uint last_minutes, time_t start_time = 0) {
            base(controller, 1000, last_minutes, start_time);
            this.end_time = end_time;
            this.end_time_object = GLib.Time.local(end_time);
        }

        public override void start() {
            base.start();
            this.duration = (int)(this.end_time - this.start_time);
        }

        public override void stop() {
            base.stop();
            this.set_text(this.end_time_object.format("Until %H:%M"));
        }

        public override void reset() {
            base.reset();
            if (this.timeout == 0) {
                this.set_text(this.end_time_object.format("Until %H:%M"));
            }
        }
    }

    public class CountupTimer : TimerLabel {
        public CountupTimer(PresentationController controller, time_t start_time = 0) {
            base(controller, start_time);
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
            if (this.time < 0) { // pretalk
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

    public class TimeOfDayTimer : TimerLabel {
        public TimeOfDayTimer(PresentationController controller) {
            base(controller);
        }

        /**
         * Just start the timer if is not running
         */
        public override void start() {
            if (this.timeout == 0) {
                this.timeout = GLib.Timeout.add(1000, this.on_timeout);
            }
            this.format_time();
        }

        public override void stop() {
            if (this.timeout != 0) {
                Source.remove(this.timeout);
                this.timeout = 0;
            }
        }

        /**
         * This timer label cannot be paused, since
         * it does not make any sense.
         */
        public override bool pause() {
            return false;
        }

        /*
         * Cannot be paused
         */
        public override bool is_paused() {
            return false;
        }

        /**
         * Start it if necessary
         */
        public override void reset() {
            this.start();
        }

        protected override void update_time() {
            // NOOP
        }

        protected override void format_time() {
            GLib.Time now = GLib.Time.local(time_t());
            uint timeInSecs = now.second + now.minute*60 + now.hour*60*60;
            this.show_time(timeInSecs, "");
        }
    }
}
