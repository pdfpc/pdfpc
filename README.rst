=====
pdfpc
=====

About
=====

pdfpc is a GTK based presentation viewer application which uses Keynote like
multi-monitor output to provide meta information to the speaker during the
presentation. It is able to show a normal presentation window on one screen,
while showing a more sophisticated overview on the other one providing
information like a picture of the next slide, as well as the left over time
till the end of the presentation. The input files processed by pdfpc are PDF
documents, which can be created using nearly any of today's presentation
software.

More information, including screenshots and a demo presentation, can be found
at https://pdfpc.github.io/

Installation
============
- On Ubuntu or Debian systems::

        sudo apt-get install pdf-presenter-console

- On Fedora::

        sudo dnf install pdfpc

- `Compiling from source <#compile-and-install>`_

Sample presentations
--------------------

- `Simple demo <https://pdfpc.github.io/demo/pdfpc-demo.pdf>`_
- `Embedded movies <https://pdfpc.github.io/demo/pdfpc-video-example.zip>`_

Try it out::

    pdfpc pdfpc-demo.pdf


Compile and install
===================

Requirements
------------

In order to compile and run pdfpc the following
requirements need to be met:

- CMake Version >=2.6
- vala >= 0.26
- GTK+ >= 3.10
- gee 0.8
- poppler with glib bindings
- gstreamer 1.0
- pangocairo

On Ubuntu systems, you can install these dependencies with::

    sudo apt-get install cmake valac libgee-0.8-dev libpoppler-glib-dev libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev

and you should consider installing all the available gstreamer codecs::

    sudo apt-get install gstreamer1.0-*

Compiling from source tarballs
------------------------------

You can download the latest stable release of pdfpc in the release section of
github (https://github.com/pdfpc/pdfpc/releases). Uncompress the tarball (we
use v4.0.2 as an example here)::

    tar xvf pdfpc-4.0.2.tar.gz

Change to the extracted directory::

    cd pdfpc-4.0.2

Compile and install::

    mkdir build/
    cd build/
    cmake ..
    make
    sudo make install

If there are no errors in the process, you just installed pdfpc on your system.
Congratulations! If there were errors, they are probably due to missing
dependencies. Please check that you have all the necessary libraries (in some
distributions you may have to install *-devel* packages).

Note: You may alter the final installation prefix in the cmake call. By default
the pdfpc files will be installed under */usr/local/*. If you want to change
that, for example to be installed under */usr/*, with config files under
*/etc/* you may specify another installation prefix as follows::

    cmake -DCMAKE_INSTALL_PREFIX="/usr" -DSYSCONFDIR=/etc ..

By default, pdfpc includes support for movie playback.  This requires several
gstreamer dependencies as well as gdk-x11.  The requirement for these packages
can be removed by compiling without support for movie playback by passing
*-DMOVIES=OFF* to the cmake command.

Compiling on Windows
--------------------

On issue #106 there is a short tutorial on how to compile pdfpc on Windows.
First a cygwin installation with the following dependencies is needed:

- cmake
- automake
- make
- gcc
- gcc-c++
- libstdc++-4.8-dev
- x11

For pdfpc the following compile time dependencies are necessary:

- vala
- gtk
- gee
- libpoppler
- gstreamer
- libgstinterfaces1.0-devel (has gstreamer.audio included)

Compiling in Mac OS X (Yosemite)
--------------------------------

First, install homebrew as described on their webpage, then install the dependencies::

    brew install cmake vala gtk+3 libgee poppler librsvg libcroco

You need to call cmake with::

    cmake -DMOVIES=off

since Yosemite has no X11 implementation, and the movie playback uses X11
features.

Compiling Trouble Shooting
--------------------------

Some distributions do not have a *valac* executable. Instead they ship with a
version suffix like *valac-0.28*. If cmake can not find your compiler you can
try running cmake with::

    cmake -DVALA_EXECUTABLE:NAMES=valac-0.28 ..


Usage
=====

Now download some [sample presentations](#sample-presentations) and load  them up::

    pdfpc pdfpc-demo.pdf

FAQ
===

Embedded video playback is not working.
---------------------------------------

You likely have a ``gstreamer`` codec issue.  First, try to install
``gstreamer``'s 'bad' codecs (package ``libgstreamer-plugins-bad1.0-0`` on
Debian/Ubuntu). By doing so, ``pdfpc`` will use ``gstreamer``'s OpenGL backend
for rendering, which might solve your issue.

If the problem persists, try loading the video file you want to play with the
following command: ``gst-launch-1.0 filesrc location=<your video> ! decodebin !
autovideosink``  If the video plays, go ahead and `submit an issue
<https://github.com/pdfpc/pdfpc/issues>`_.  Otherwise, the command will likely
output some good hints for why gstreamer cannot decode the video.


Windows do not appear on the correct screen.
---------------------------------------------------

For tiling window managers, the movement and fullscreening of the windows do not work reliable.
It is therefore important to tell your WM to force floating the pdfpc windows.

If you are using i3-wm add this to your config file::

    for_window [ title="^pdfpc - present" ] border none floating enable

Acknowledgements
================

pdfpc has been developed by Jakob Westhoff, David Vilar, Robert Schroll, Andreas
Bilke, Andy Barry, Phillip Berndt and others. It was previously available at
https://github.com/davvil/pdfpc

pdfpc is a fork of Pdf Presenter Console by Jakob Westhoff, available at
https://github.com/jakobwesthoff/Pdf-Presenter-Console
