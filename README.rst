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

- On archlinux::

        sudo pacman -S pdfpc

- On FreeBSD::

        It's available under graphics/pdfpc. A pre built binary is also available.

- On macOS with MacPorts::

        # Nice macOS integration, but no video support currently
        sudo port -v install pdfpc +quartz

        # Video support, but window placing might not work well
        sudo port -v install pdfpc +x11

- On Windows 10 (with *Windows Subsystem for Linux (WSL)*)::

        Install:
        1. Windows: Activate WSL: https://msdn.microsoft.com/en-us/commandline/wsl/install_guide
        2. Windows: Open CMD and run: 'bash' in order to start the WSL-bash
        3. WSL-Bash: run: 'sudo apt-get install pdf-presenter-console'

        Run:
        1. Windows: Install a Windows X-Server like VcXsrv: https://sourceforge.net/projects/vcxsrv
        2. Windows: Make the presentation screen your secondary screen and disable the taskbar on that screen
        3. Windows: Start the X-Server with: 'vcxsrv -nodecoration -screen 0 @1 -screen 1 @2 +xinerama'
        4. Windows: Open CMD and run: 'bash' in order to start the WSL-bash
        5. WSL-Bash: run: 'DISPLAY=:0 pdfpc <your PDF file>' to open your presentation with pdfpc

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

- CMake Version >=3.0
- vala >= 0.34
- GTK+ >= 3.22
- gee 0.8
- poppler with glib bindings
- gstreamer 1.0
- pangocairo

On Ubuntu 18.04 onwards, you can install these dependencies with::

    sudo apt-get install cmake valac libgee-0.8-dev libpoppler-glib-dev libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-gtk3

(the latter is a run-time dependence). You should also consider installing all
plugins to support required video formats; chances are they are already present
through dependencies of ``ubuntu-desktop``.

Compiling from source tarballs
------------------------------

You can download the latest stable release of pdfpc in the release section of
github (https://github.com/pdfpc/pdfpc/releases). Uncompress the tarball (we
use v4.2.1 as an example here)::

    tar xvf pdfpc-4.2.1.tar.gz

Change to the extracted directory::

    cd pdfpc-4.2.1

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

Compiling Trouble Shooting
--------------------------

Some distributions do not have a *valac* executable. Instead they ship with a
version suffix like *valac-0.40*. If cmake can not find your compiler you can
try running cmake with::

    cmake -DVALA_EXECUTABLE:NAMES=valac-0.40 ..

Usage
=====

Now download some [sample presentations](#sample-presentations) and load  them up::

    pdfpc pdfpc-demo.pdf

If you encounter problems while running pdfpc, please consult the `FAQ
<FAQ.rst>`_ first.

Acknowledgements
================

pdfpc was initially developed as pdfpc-presenter-console by Jakob Westhoff
(https://github.com/jakobwesthoff/Pdf-Presenter-Console)
then further extended by davvil (https://github.com/davvil/pdfpc).

