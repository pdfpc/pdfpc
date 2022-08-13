/**
 * Timer/stopwatch/clock
 *
 * This file is part of pdfpc.
 *
 * Copyright 2022 Evgeny Stambulchik
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
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
     * Auxiliary function to parse time string, returning Unix time
     */
    time_t parse_time(string t) {
        int hours = 0, minutes = 0;
        t.scanf("%d:%d", &hours, &minutes);

        var dt_now = new DateTime.now();
        var hours_now = dt_now.get_hour();
        var minutes_now = dt_now.get_minute();
        var seconds_now = dt_now.get_second();

        var diff_minutes = 60*(hours - hours_now) + (minutes - minutes_now);
        if (diff_minutes < 0) {
            // Assume it's about tomorrow
            diff_minutes += 60*24;
        }

        var dt = dt_now.add_minutes(diff_minutes);

        // Round down to full minutes
        dt = dt.add_seconds(-seconds_now);

        return (time_t) dt.to_unix();
    }

    /**
     * The timer object
     */
    public class Timer: GLib.Object {
        /**
         * Display mode
         */
        public enum Mode {
            Clock,
            CountUp,
            CountDown;
        }

        /**
         * Operational state
         */
        public enum State {
            Stopped,
            PreTalk,
            Running,
            Paused;
        }

        /**
         * Intended start time of the talk
         */
        protected time_t intended_start_time = 0;

        /*
         * Duration of the talk
         */
        public int duration { get; protected set; default = 0; }

        /**
         * Actual start time of the talk
         */
        protected time_t start_time = 0;

        /**
         * Current state
         */
        protected Timer.State state = State.Stopped;

        /**
         * Display mode
         */
        protected Mode mode = Mode.CountUp;

        /**
         * Current time, updated every second
         */
        protected time_t now = 0;

        /**
         * Time in seconds the presentation has been running. A negative value
         * indicates the pretalk mode.
         */
        protected int running_time = 0;

        /**
         * Signal: fired when the timer label changes
         */
        public signal void change(int time, State state, string label);

        /**
         * Constructor
         */
        public Timer(int duration = 0, string? start_time_str = null,
                     string? end_time_str = null) {
            time_t intended_end_time = 0;

            // If all three values are given, ignore duration and print error
            if (start_time_str != null && end_time_str != null &&
                duration > 0) {
                printerr("Start and stop times given, duration is ignored\n");
            }

            this.duration = duration;

            this.now = time_t();

            if (start_time_str != null) {
                this.intended_start_time = parse_time(start_time_str);
            }
            if (end_time_str != null) {
                intended_end_time = parse_time(end_time_str);
            }

            if (this.intended_start_time > 0 && intended_end_time > 0) {
                if (this.intended_start_time >= intended_end_time) {
                    // Assume an over-midnight talk...
                    intended_end_time += 24*3600;
                }
                this.duration = (int) (intended_end_time -
                    this.intended_start_time);
            } else
            if (intended_end_time > 0 && duration > 0) {
                intended_start_time = intended_end_time - duration;
            }

            if (intended_start_time > 0) {
                this.state = State.PreTalk;
            }

            if (this.duration > 0) {
                this.mode = Mode.CountDown;
            }

            // Start the clock
            GLib.Timeout.add(1000, this.on_timeout);
        }

        /**
         * Get mode
         */
        public Mode get_mode() {
            return this.mode;
        }

        /**
         * Set mode, returning true/false on success/failure.
         * If the mode changes, update the view.
         */
        public bool set_mode(Mode new_mode) {
            if (new_mode == Mode.CountDown && this.duration == 0) {
                // This combination makes no sense
                return false;
            }

            if (this.mode != new_mode) {
                this.mode = new_mode;
                this.update();
            }

            return true;
        }

        /**
         * Cycle the mode (count up/count down/current time)
         */
        public void cycle_mode() {
            switch (this.mode) {
            case Mode.Clock:
                this.set_mode(Mode.CountUp);
                break;
            case Mode.CountUp:
                if (this.set_mode(Mode.CountDown) != true) {
                    this.set_mode(Mode.Clock);
                }
                break;
            case Mode.CountDown:
                this.set_mode(Mode.Clock);
                break;
            }
        }

        /**
         * Start the timer
         */
        public void start() {
            if (this.state != State.Stopped && this.state != State.PreTalk) {
                return;
            }

            this.start_time = this.now;
            this.state = State.Running;
        }

        /**
         * Start or continue running
         */
        public void run() {
            switch (this.state) {
            case State.Stopped:
            case State.PreTalk:
                this.start();
                break;
            case State.Running:
                break;
            default:
                this.start_time = this.now - this.running_time;
                this.state = State.Running;
                break;
            }
        }

        /**
         * Toggle the pause mode. Return true if the timer is paused.
         */
        public bool toggle_pause() {
            switch (this.state) {
            case State.Paused:
                this.run();
                break;
            case State.Running:
                this.state = State.Paused;
                break;
            default:
                break;
            }

            return is_paused();
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
        public void reset() {
            if (this.state == State.PreTalk) {
                // We are in the pretalk mode; nothing to do
                return;
            }

            if (this.intended_start_time > 0) {
                if (this.now < this.intended_start_time) {
                    this.start_time = this.intended_start_time;
                    this.state = State.PreTalk;
                } else {
                    // Past the desired start time, resetting makes no sense
                }
            } else {
                this.state = State.Stopped;
            }

            this.update();
        }

        /**
         * Return true if the timer has been (manually) paused
         */
        public bool is_paused() {
            return (this.state == State.Paused);
        }

        /**
         * Return true if the timer is running
         */
        public bool is_running() {
            return (this.state == State.Running);
        }

        /**
         * Update the timer on every timeout step
         */
        protected bool on_timeout() {
            this.now = time_t();
            if (intended_start_time > 0 && this.now > intended_start_time) {
                // this.start() takes care of required conditions
                this.start();
            }

            if (this.mode == Mode.Clock ||
                this.state == State.PreTalk || this.state == State.Running) {
                this.update();
            }

            // The show must go on
            return true;
        }

        /**
         * Update and format time label
         */
        protected void update() {
            // NB: running_time is negative if the talk begins in future
            switch (this.state) {
            case State.PreTalk:
                this.running_time = (int) (this.now - this.intended_start_time);
                break;
            case State.Running:
                this.running_time = (int) (this.now - this.start_time);
                break;
            case State.Stopped:
                this.running_time = 0;
                break;
            default:
                break;
            }

            // Begin formatting
            uint hours = 0, minutes = 0, seconds = 0;
            int timeInSecs = 0;

            switch (this.mode) {
            case Mode.Clock:
                var dt = new DateTime.now_local();
                seconds = dt.get_second();
                minutes = dt.get_minute();
                hours   = dt.get_hour();
                break;
            case Mode.CountUp:
                timeInSecs = this.running_time;
                break;
            case Mode.CountDown:
                switch (this.state) {
                case State.PreTalk:
                    timeInSecs = this.running_time;
                    break;
                default:
                    timeInSecs = this.duration - this.running_time;
                    break;
                }
                break;
            }

            string prefix = "";
            if (timeInSecs != 0) {
                if (timeInSecs < 0) {
                    timeInSecs = -timeInSecs;
                    prefix = "-";
                }
                hours   = timeInSecs/3600;
                minutes = timeInSecs/60 % 60;
                seconds = timeInSecs % 60;
            }

            int talk_time = this.running_time > 0 ? this.running_time : 0;

            // Tell everybody subscribed to the signal
            this.change(talk_time, this.state,
                "%s%.2u:%.2u:%.2u".printf(prefix, hours, minutes, seconds));
        }
    }
}
