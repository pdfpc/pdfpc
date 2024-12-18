===============
pdfpc Changelog
===============

Version 4.7.0
=============

*Released: December 2024*

- Various bug fixes and improvements
- Support for newer library dependencies

Version 4.6.0
=============

*Released: December 2022*

- Support hidden slides
- Poster images for videos
- Undo/Redo for slide drawings
- JSON-schema for .pdfpc file
- Simple REST-server for remote control

Version 4.5.0
=============

*Released: December 2020*

- **Switch to GPLv3+ licence**
- JSON format for pdfpc file
- Markdown support for text notes
- Render LaTeX beamer and text notes in the same place
- Per-overlay notes
- Zoom feature in highlighted areas
- Spotlight mode
- Page transitions
- Automatic slide advancing
- Video controls in presentation window
- Max/unmax current slide view in presenter
- Consistency with pdfpc/command line overriding of options
- Allow run-time GUI customization
- Assorted bug fixes

Version 4.4.1
=============

*Released: November 2020*

Bug fix release:

- Compatibility with pdfpc LaTeX package
- Some UI glitches
- Icon rendering with HiDPI
- Allow multiple videos per slide

Version 4.4.0
=============

*Released: February 2020*

- Document reload
- Resizable windows
- Toggling between windowed and full screen mode
- Cheatsheet in application for key/mouse bindings
- PnP for monitors
- Improved caching behaviour (pdfpc will not lock the GUI during cold start)
- Support for XMP meta data and notes (see the CTAN pdfpc package)
- Hide pointer after a period of inactivity
- Windowed mode is now a pdfpcrc option
- Pressure sensitivity of input devices
- Forward history
- Support for executing external scripts
- DBus actions with arguments

- Bug fixes

Version 4.3.4
=============

*Released: June 2019*

- Fix loading of key bindings

Version 4.3.3
=============

*Released: June 2019*

- Better video playback support on Mac OS X

Version 4.3.2
=============

*Released: February 2019*

- Fix compile error on some distributions

Version 4.3.1
=============

*Released: January 2019*

- Fix --notes= behaviour
- Fix default key bindings for last/first overlay

Version 4.3.0
=============

*Released: December 2018*

- *Backward incompatible changes*
    - Improvement/more logical default key bindings
    - GTK+3 >= 3.22

- Four-State operation mode
    - makes handling of drawing, eraser and pointer mode much easier

- Permament setting of pointer color and size in pdfpcrc

- Window placement can be done by monitor name

- Subtitles for video playback

- Different slide sizes per presentation are allowed

- Bug fixes
    - Wayland high DPI scaling issues
    - Window placement issues with some WMs

Version 4.2.1
=============

*Released: October 2018*

- Bug fix: Add missing icons to CMakeLists.txt

Version 4.2
===========

*Released: October 2018*

- Toolbar for pen/eraser/pointer mode (e.g. for touch screens)

- Jump to first overlay

- Bug fixes
    - Print proper error messages if gstreamer fails to load because of missing plugins
    - Fix freeze mode in combination with video slides
    - Fix race conditions in gstreamer video pipeline (e.g. when the user switches
      slides 'too fast')
    - Jumping to last overlay works reliable
    - Video controls are working now with shown drawings on that slide

Version 4.1.2
=============

*Released: May 2018*

- Quick bug fix: restore good pixel rendering quality for non-annotated PDFs
- Fix version string for pdfpc --version

Version 4.1.1
=============

*Released: May 2018*

- Bug fixes
    - Linking paths for some operation systems
    - Correctly clickable links in PDF
    - Color hints in timer
    - Disable wayland scaling workaround by default
    - Hide video if used with beamer notes

Version 4.1
===========

*Released: October 2017*

- Time pace color (adaptive color changes of the timer depending on the
  presenters speed)

- PDF annotations can be used as slide notes

- The .pdfpc file can now be located at different locations

- The .pdfpc file allows a notes include file

- Main window can be hidden during the talk

- Bug fixes
    - Font increasing/decreasing of notes works more reliable
    - Fix segfault if all slides are marked as overlays
    - Wayland with HiDPI setting should have the correct window size

Version 4.0.8
=============

*Released: August 2017*

- Bug fixes
    - Respects playmode for movies embedded with multimedia package
    - More reliable movie playback (needs gstreamer-plguins-bad now!)
    - Fix bug in overlay detection

- Pen drawing mode (allows user to draw on slides)


Version 4.0.7
=============

*Released: June 2017*

- Small bug fixes
    - Store last_minute correctly in pdfpc file
    - Use a new default gstreamer sink for video playing
      (fixes an issue where the sound work, but the video not)
    - High CPU usage for some videos when the video is paused
    - Fixed a crash for some video drivers

- Works with vala 0.36

- PDFPC can now store the last viewed slide to restore it
  at a later session

- A user can now skip already viewed overlays (and jump
  to the full slide directly)

Version 4.0.6
=============

*Released: February 2017*

- New command line option: -P/--page jump to a specific page after
  startup

- HiDPI support. Respect GDK Hints about HiDPI screens.
  This resolves an issue, where the slides where rendered blurry

- Escape special characters in text nodes. This resolves an
  issue where all text notes got lost if special characters where
  used.

- Allow more permanent config options per pdf/globally

- Resolve unfullscreening/out of screen bugs in low resolution or HiDPI
  scenarios

- Better Wayland support

- Overview slides contain the actual slide number to
  find specific slides faster

- Documentation improvements

Version 4.0.5
=============

*Released: January 2017*

- Persistent PNG cache for faster startup

- Layout fix:
    - CSS fix for older GTK versions
    - Fixed prev-slide semantics
    - Next-slide view shows full slide in case of overlays
    - Fix highlighting in overview mode (removed pixman error in logs)
    - Enforced timer/status bar height. this area no longer "jumps" if icons
      are displayed

- Overview mode: click on slide goes to full slide (in case of overlays), SHIFT
  + click goes to the first slide

- Fixed history-back semantics

- Split man pages in pdfpc(1) for the program and pdfpcrc(5) for config file
  options


Version 4.0.4
=============

*Released: November 2016*

- auto-workaround for notes and auto-grouping bug

- fix CSS for newer GTK versions

Version 4.0.3
=============

*Released: October 2016*

- Compiles with vala 0.32

- pdfpc can now show some highlighting pointer

- Adds D-Bus Server for controlling pdfpc

- Minor Improvements:
    - Search pdfpcrc files in XDG compliant directories
    - Key shortcut to jump to the last overlay
    - Made progress bar in movie playback optional


Version 4.0.2
=============

*Released: February 2016*

- Adds a option, -g, to disable auto-grouping of overlay slides

- Removes some command line options in favor of a configuration file, pdfpcrc

- Bug fixes:
    - Movies with an end-time now correctly loop
    - Fixes cut-off text in a number of cases
    - Fixes issues where the screens might not move to the correct monitor
    - Other small fixes


Version 4.0.1
=============

*Released: November 2015*

- Keybindings for changing font size of the notes view

- Hyperlinks to web pages are now opened in the web browser

- Instead of count downs, the current time can be displayed

- start/stop, noaudio attributes for movies

- The user can now configure the presenter view layout according to their needs

- Movie support can be disabled to allow compilation on Mac OS X / Windows (via
  cmake -DMOVIES=OFF)

- Bug fixes


Version 4.0
=============

*Released: June 2015*

- *Major* Moved to GTK+3

- New Maintainer

- Movie playback, based on gstreamer 1.0

- Support LaTeX beamer slides with notes

- Option to sepcify size in windowed mode

- Various bug fixed and documentation
  improvements

Version 3.1.1
=============

*Released: July 2012*

- Bug fix for released C sources

Version 3.1
===========

*Released: June 2012*

- Revamped overview mode, with better keyboard navigation support and better visual
  appearance (thanks to rschroll)

- Support for configuration files. Now all keybindings are configurable

- Improved layout management (thanks to rschroll)

- (Hopefully) Improved handling of fullscreen modes

Version 3.0
===========

*Released: May 2012*

- Renamed to pdfpc (forked from Pdf Presenter Console)

- Support for new poppler version

- Support for (textual) notes

- Support for overlays

- Overview mode

- Jump to slides by inputting the slide number

- Movement in 10-slide blocks allowed using shift

- Two additional timer modes: countup and end time of presentation

- Pause timer (useful for rehearsal talks)

- Support for mouse wheel (thanks to mikerofone) and bluetooth headset controls
  (thanks to NerdyProjects)

- Freezing and blacking out of presentation view

- Presenter view starts on primary screen

- Definition of "end slide"

- Navigable history of jumps

===============================
Pdf Presenter Console Changelog
===============================

Version 2.0
===========

*Released: 16. Jan 2010*

- Complete rewrite of rendering system to allow more sophisticated actions.

- Changed license of the project from GPLv3 to GPLv2+ because of
  incompatibilities with Poppler. (Thanks to Jakub Wilk <jwilk@debian.org> and
  Barak A. Pearlmutter <barak@cs.nuim.ie> for pointing out this out).

- Implemented: Usage of left-/right mousebuttons for slide navigation.

- Implemented: Handling of navigational links inside of PDF files.

- Implemented: Abstraction to cache prerendered slides.

- Implemented: Compressed cache for prerendered slides.

- Implemented: Alternative way of executing the prerendering process to allow
  for smoother navigation while slides are generated.

- Implemented: Means to switch displays in single monitor mode as well as dual
  monitor mode

- Implemented: Disabled timer if a duration of 0 is provided

- Fixed: Build problems on Fedora 13 due to changed linking procedure

- Fixed: Slightly changed image data formats due to update of Gtk to Version
  2.22 or higher.

- Implemented: Removed usage of deprecated Gdk.GC in favor of Cairo.


Version 1.1.1
=============

- Fixed: Compile error with newer vala versions due to wrong property
  visibility

- Fixed: Typo in help text


Version 1.1
===========

- Implemented: Controllable interface for cleaner controller code.

- Fixed: Install target is now executable.

- Fixed: Warnings shown in one-screen-presentation-mode, due to non existant
  process indicator.

- Implemented: Presentation timer as its own GTK Widget

- Implemented: Support for negative timer values (aka overtime)

- Implemented: Different Timer colors for normal time, the last x minutes and
  overtime

- Implemented: Made last-minutes time configurable

- Fixed: Library paths were not used correctly for compilation

- Implemented: Fullscreen window as own Gtk class

- Fixed: Problem which caused the windows not be displayed on the correct
  displays using the Xfce4 Xfwm window mananger.

- Implemented: Command line option to set the size of the current slide in the
  presenter screen

- Implemented: A few more common key bindings

- Implemented: Hide cursor after 5 seconds timeout


Version 1.0
===========

- Initial release
