=====================
Pdf Presenter Console
=====================

About
=====

The Pdf Presenter Console (PPC) is a GTK based presentation viewer application
which uses Keynote like multi-monitor output to provide meta information to the
speaker during the presentation. It is able to show a normal presentation
window on one screen, while showing a more sophisticated overview on the other
one providing information like a picture of the next slide, as well as the left
over time till the end of the presentation. The input files processed by PPC
are PDF documents, which can be created using nearly any of today's presentation
software.

Motivation
==========

The idea to create PPC came up during the IPC 2009 where I saw a lot of people
running around with their MacBooks using Keynote to present their slides. I
always liked the presenter console of Keynote. Therefore I began to research if
any solution like this existed for my Linux system. I came across the Sun
presenter console for Open-Office Impress, which seemed to do exactly what I
wanted. Unfortunately I stopped using Impress for creating presentations in
favor to Latex Beamer quite some time ago. Therefore this Open-Office plugin was
no solution to my problem. I wanted something flexible which would be able to
use simple PDF documents as input. I found some projects which were started
having the same intentions than I did. Unfortunately these projects did either
never reach the implementation phase or they were implemented but I did not get
them to work properly. 

All this brought me to the decision to create a simple presenter console on my
own. At this point the Pdf Presenter Console was born.

Requirements
============

In order to compile and run the Pdf Presenter Console the following
requirements need to be met:

- Vala Compiler Version >=0.11.0
- CMake Version >=2.6
- Gtk+ 2.x
- libPoppler with glib bindings
- librsvg

Compile and install
===================

After retrieving the archive unpack it using the following command::

    tar xvzf pdf_presenter_console-VERSION.tar.gz

Switch to the unpacked source directory and create some sort of build
directory. This may be done as follows::

    cd pdf_presenter_console-VERSION
    mkdir build
    cd build

After you are inside the build directory create the needed Makefiles using
CMake::

    cmake ../

If you have put your build directory elsewhere on your system adapt the path
above accordingly. You need to provide CMake with the pdf_presenter_console
directory which you just decompressed.

You may alter the final installation prefix at this time. By default the
pdf_presenter_console executable will be installed under */usr/local/bin*. If
you want to change that, for example to be */usr/bin* you may specify another
installation prefix as follows::

    cmake -DCMAKE_INSTALL_PREFIX="/usr" ../

If all requirements are met CMake will tell you that it created all the
necessary build files for you. If any of the requirements were not met you
will be informed of it to provide the necessary files or install the
appropriate packages.

The next step is to compile the source using GNU Make or any other make
derivative you may have installed. Simply issue the following command to start
building the application::

    make

After the build completes successfully the *pdf_presenter_console* executable
can be found inside the *src* directory of you build path. If you want to
install it automatically to the *bin* directory below the before provided
prefix do as follows::

    make install

You may need to prefix this command with a *sudo* or obtain super-user rights
in any other way applicable to your situation.

Congratulations you just installed Pdf Presenter Console on your system.


Retrieving the current trunk from the softwares git repository
--------------------------------------------------------------

If you want to use the bleeding edge version of this software, you may always
retrieve the current development branch from its git repository. Do this on
your own risk. It may not compile, make your socks disappear or even eat your
cat ;).

The repository is hosted at github__. If the git executable is available on
your system it can be retrieved using the following command::

    git clone git://github.com/jakobwesthoff/Pdf-Presenter-Console.git

After it has been transfered you need to switch to the
``Pdf-Presenter-Console`` directory, which has just been created. From inside
this directory use these commands to retrieve all needed submodules::

    git submodule init
    git submodule update

You are now set to compile and install the presenter as described in the
section above. However as mentioned above the code might not compile at all.


__ http://github.com/jakobwesthoff/Pdf-Presenter-Console


Startup and usage
=================

The Pdf Presenter Console is run by calling it's executable on the commandline
followed by the pdf you want to present::

    pdf_presenter_console your/pdf/file.pdf

Calling the application like this is the easiest way to go. There are certain
commandline options you may use to customize the behavior of the presenter to
your likings::

    Usage:
      pdf_presenter_console [OPTION...] <pdf-file>

    Help Options:
      -h, --help                    Show help options

    Application Options:
      -d, --duration=N              Duration in minutes of the presentation used for timer display. (Default 45 minutes)
      -l, --last-minutes=N          Time in minutes, from which on the timer changes its color. (Default 5 minutes)
      -u, --current-size=N          Percentage of the presenter screen to be used for the current slide. (Default 60)
      -s, --switch-screens          Switch the presentation and the presenter screen.
      -c, --disable-cache           Disable caching and pre-rendering of slides to save memory at the cost of speed.
      -z, --disable-compression     Disable the compression of slide images to trade memory consumption for speed. (Avg. factor 30)
      -b, --black-on-end            Add an additional black slide at the end of the presentation
      -S, --single-screen=S         Force to use only one screen

Caching / Prerendering
----------------------

To allow fast changes between the different slides of the presentation the pdf
pages are prerendered to memory. The progress bar on the bottom of the
presenter screen indicates how many percent of the slides have been
pre-rendered already. During the initial rendering phase this will slow-down
slide changes, as a lot of cpu power is used for the rendering process in the
background. After the cache is fully primed however the changing of slides
should be much faster as with normal pdf viewers.

As the prerendering takes a lot of memory it can be disabled using the
*--disable-cache* switch at the cost of speed.


Cache compression
-----------------

Since version 2.0 of the Pdf-Presenter-Console the prerendered and cached
slides can be compressed in memory to save up some memory. Without compression
a set of about 100 pdf pages can easily grow up to about 1.5gb size. Netbooks
with only 1gb of memory would swap themselves to death if prerendering is
enabled in such a situation. The compression is enabled by default as it does
not harm rendering speed in a noticeable way on most systems. It does however
slows down prerendering by about a factor of 2. If you have got enough memory
and want to ensure the fastest possible prerendering you can disable slide
compression by using the *-z* switch. But be warned using the uncompressed
prerendering storage will use about 30 times the memory the new compressed
storage utilizes (aka the 1.5gb become about 50mb)


Keybindings
-----------

During the presentation the following key strokes and mouse clicks are detected
and interpreted:

- Left cursor key / Page up / Right mouse button 
    - Go back one slide
- Up cursor key
    - Go back on "user slide" (see section about overlays below)
- Backspace / p
    - Go back 10 slides
- Right cursor key / Page down / Return / Space / Left mouse button
    - Go forward one slide
- Down cursor key
    - Go forward one user slide
- n
    - Go forward 10 slides
- Home
    - Go back to the first slide and reset the timer
- g
    - Input a slide number to jump to
- Escape / q /Alt+F4
    - Quit the presentation viewer
- b
    - Turn off the presentation view at the end (i.e. fill it with a black color)
- e
    - Edit note for current slide
- f
    - Freeze the current presentation display (the presenter display is still
      fully active)
- o
    - Toggle the not-user-slide flag for one particular slide (see Overlays
      below)

Timer
-----

The timer is started if you are navigating away from the first page for the
first time. This feature is quite useful as you may want to show the titlepage
of your presentation while people are still entering the room and the
presentation hasn't really begun yet. If you want to start over you can use the
*Home* key which will make the presenter go back to the first page and reset
the timer as well.

At the moment the timer reaches the defined ``last-minutes`` value it will
change color to indicate your talk is nearing its end.

As soon as the timer reaches the zero mark (00:00:00) it will turn red and
count further down showing a negative time, to provide information on how many
minutes you are overtime.

Notes
-----

Textual notes can be displayed for each slide. While in the presentation,
pressing 'e' will allow you to take notes for the screen.  To go out of editing
mode, press the Escape key. Note that while editing a note the keybindings stop
working, i.e. you are not able to change slides.

The notes are stored in the given file in a plain text format, easy to edit
also from outside the program. See the section about the pdfpc format below.

Overlays
--------

Many slide preparation systems allow for overlays, i.e. sets of slides that
are logically grouped together as a single, changing slide. Examples include
enumerations where the single items are displayed one after another or rough
"animations", where parts of a picture change from slide to slide. Pdf
Presenter Console includes facilities for dealing with such overlays.

In this description, we will differentiation between slides (i.e. pages in the
pdf document) and "user slides", that are the logical slides. The standard
forward movement command (page down, enter, etc.) moves through one slide at a
time, as expected. That means that every step in the overlay is traversed.
The backward movement command works differently depending if the current and
previous slides are part of an overlay:

- If the current slide is part of an overlay we just jump to the previous
  slide. That means that we are in the middle of an overlay we can jump
  forward and backward through the single steps of it

- If the current slide is not part of an overlay (or if it is the first one),
  but the previous slides are, we jump to the previous user slide. This means
  that when going back in the presentation you do not have to go through every
  step of the overlay, Pdf Presenter Console just shows the first slide of
  the each overlay. As you normally only go back in a presentation when looking
  for a concrete slide, this is more convenient.

The up and down cursor keys work on a user slide basis. You can use them to
skip the rest of an overlay or to jump to the previous user slide, ignoring the
state of the current slide. The 'n' and 'p' commands also work on a user slide
basis.

When going through an overlay, two additional previews may be activated in the
presenter view, just below the main view, showing the next and the previous
slide in an overlay.

Pdf Presenter Console tries to find these overlays automatically by looking
into the page labels in the pdf file. For LaTeX this works correctly at least
with the beamer class and also modifying the page numbers manually (compiling
with pdflatex). If you preferred slide-producing method does not work correctly
with this detection, you can supply this information using the 'o' key for each
slide that is part of an overlay (except the first one!). The page numbering is
also adapted. This information is automatically stored.

pdfpc Files
-----------

The notes and the overlay information (if manually edited) are stored in a file
with the extension "pdfpc". When invoking Pdf Presenter Console with a non
pdfpc file, it automatically checks if there exists such a file and in this
case loads the additional information. This means that you normally do not have
to deal with this kind of files explicitly.

There are however cases where you may want to edit the files manually. The most
typical case is if you add or remove some slides after you have edited notes or
defined overlays. It may be quicker to edit the pdfpc file than to re-enter the
whole information. Future versions may include external tools for dealing with
this case automatically.

The files are plain-text files that should be fairly self-explanatory. A couple
of things to note
- The slide numbers of the notes refer to user slides
- The [notes] sections must be the last one in the file
- For the programmers out there: slide indexes start at 1

Download
========

The most recent release can always be obtained from:

    http://westhoffswelt.de

The latest and bleeding edge development version can be obtained by checking
out the development git repository using the following command::

    $ git clone git://github.com/jakobwesthoff/Pdf-Presenter-Console.git

The trunk version is not guaranteed to build or be working correctly. So be
warned if you use it. 


Contact
=======

Every comment or idea for a future version of this presenter is welcome. Just
send a mail to jakob@westhoffswelt.de. 

Other ways of contact can be retrieved through visiting

    http://westhoffswelt.de



..
   Local Variables:
   mode: rst
   fill-column: 79
   End: 
   vim: et syn=rst tw=79
