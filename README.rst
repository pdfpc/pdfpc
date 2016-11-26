=====
pdfpc
=====

About
=====

pdfpc is a GTK based presentation viewer application for GNU/Linux which uses
Keynote like multi-monitor output to provide meta information to the speaker
during the presentation. It is able to show a normal presentation window on one
screen, while showing a more sophisticated overview on the other one providing
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
- `Compiling from github <#compiling-from-github>`_

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

On Ubuntu systems, you can install these dependencies with::

    sudo apt-get install cmake libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgee-0.8-dev librsvg2-dev libpoppler-glib-dev libgtk2.0-dev libgtk-3-dev valac

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

Compiling from github
---------------------

If you want the bleeding-edge version of pdfpc, you should checkout the git
repository. The *master* branch should be fairly stable and safe to use.

The pdfpc source can be retrieved from github::

    git clone git://github.com/pdfpc/pdfpc.git

After it has been transfered you need to switch to the ``pdfpc`` directory,
which has just been created.

You are now set to compile and install pdfpc.  Start by creating a build
directory (this is optional but it keeps the directories clean, in case you
want to do some changes)::

    mkdir build/
    cd build/

After you are inside the build directory create the needed Makefiles using
CMake::

    cmake ..

If you have put your build directory elsewhere on your system adapt the path
above accordingly. You need to provide CMake with the pdfpc directory as
created by git. As pointed out before, you may alter the installation
directories via the *-DCMAKE_INSTALL_PREFIX* and *-DSYSCONFDIR* command line
arguments.

If all requirements are met, CMake will tell you that it created all the
necessary build files for you. If any of the requirements were not met you will
be informed of it to provide the necessary files or install the appropriate
packages.

The next step is to compile and install pdfpc using GNU Make or any other make
derivative you may have installed. Simply issue the following command to start
building the application::

    make
    sudo make install

Congratulations you just installed pdfpc on your system.

Compiling on Windows
--------------------

On issue #106 there is a short tutorial on how to compile pdfpc on Windows.
First a cygwin installation with the following depedencies is needed:

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

    brew install cmake vala gtk+3 libgee poppler

You need to call cmake with::

    cmake -DMOVIES=off

since Yosemite has no X11 implementation, and the movie playback uses X11
features. Note that the icons don't load (see issue #179)

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
* Embedded video playback is not working.
 * You likely have a ``gstreamer`` codec issue.  Try loading the video file you want to play with the following command: ``gst-launch-1.0 filesrc location=<your video> ! decodebin ! autovideosink``  If the video plays, go ahead and `submit an issue <https://github.com/pdfpc/pdfpc/issues>`_.  Otherwise, the command will likely output some good hints for why gstreamer cannot decode the video.

Acknowledgements
================

pdfpc has been developed by Jakob Westhoff, David Vilar, Robert Schroll, Andreas
Bilke, Andy Barry, and others.  It was previously available at
https://github.com/davvil/pdfpc

pdfpc is a fork of Pdf Presenter Console by Jakob Westhoff, available at
https://github.com/jakobwesthoff/Pdf-Presenter-Console
