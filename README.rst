=====
pdfpc
=====

About
=====

pdfpc is a GTK-based presentation application which uses Keynote-like
multi-monitor output to provide meta information to the speaker during the
presentation. It is able to show a normal presentation window on one screen,
while showing a more sophisticated overview on the other one, providing
information like an image of the next slide, time remaining till the end of
the presentation, etc. The input files processed by pdfpc are PDF documents,
which can be created by most of the present-day presentation software.

More information, including screenshots and demo presentations, can be found
at https://pdfpc.github.io/

Installation
============

- On Debian, Ubuntu, and other Debian-based systems::

    sudo apt-get install pdf-presenter-console

- On Fedora::

    sudo dnf install pdfpc

- On Arch Linux::

    sudo pacman -S pdfpc

- On Gentoo::

    sudo emerge --ask pdfpc

- On FreeBSD::

    sudo pkg install pdfpc
    # It is also available under graphics/pdfpc in the ports tree.

- On macOS with Homebrew::

    # Full macOS integration, including video support
    brew install pdfpc

- On macOS with MacPorts::

    # Nice macOS integration, including video support
    sudo port -v install pdfpc +quartz +video

    # Less well integrated due to using X11 server, video supported
    sudo port -v install pdfpc +x11 +video

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
====================

- `Simple demo <https://github.com/pdfpc/pdfpc/releases/latest/download/pdfpc-demo.pdf>`_
- `Embedded movies <https://github.com/pdfpc/pdfpc/releases/latest/download/pdfpc-video-example.zip>`_

Usage
=====

Try it out::

    pdfpc pdfpc-demo.pdf


If you encounter problems while running pdfpc, please consult the `FAQ
<FAQ.rst>`_ first.

Compilation from sources
========================

Requirements
------------

In order to compile and run pdfpc, the following requirements need to be met:

- cmake >= 3.0
- vala  >= 0.34
- gtk+  >= 3.22
- gee   >= 0.8
- poppler with glib bindings
- pangocairo
- gstreamer >= 1.0 with gst-plugins-good
- discount (aka markdown2)
- webkit2gtk
- json-glib
- libsoup
- libqrencode

E.g., on Ubuntu 18.04 onward, you can install these dependencies with::

    sudo apt-get install cmake valac libgee-0.8-dev libpoppler-glib-dev
    libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
    libjson-glib-dev libmarkdown2-dev libwebkit2gtk-4.0-dev libsoup2.4-dev
    libqrencode-dev gstreamer1.0-gtk3

(the last one is a run-time dependence). You should also consider installing all
plugins to support required video formats; chances are they are already present
through dependencies of ``ubuntu-desktop``.

On macOS with Homebrew, the easiest way is to install all dependencies of the
pdfpc package without pdfpc itself::

    brew install --only-dependencies pdfpc

On macOS with MacPorts, you can install all dependencies using the `port` command::

    # list dependencies for the +quartz +video variant
    # (good macOS integration)
    port deps pdfpc +quartz +video
    # install dependencies
    sudo port -v install cmake vala pkgconfig gtk3 +quartz poppler libgee librsvg gstreamer1-gst-plugins-good +gtk3

    # list dependencies for the +x11 +video variant
    # (using X11 server)
    port deps pdfpc +x11 +video
    # install dependencies
    sudo port -v install cmake vala pkgconfig gtk3 +x11 poppler libgee librsvg gstreamer1-gst-plugins-good +gtk3 +x11

On Windows with MSYS2/MinGW-w64, the dependencies are installed with::

    pacman -S mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-gcc mingw-w64-x86_64-pkg-config mingw-w64-x86_64-vala mingw-w64-x86_64-libgee mingw-w64-x86_64-poppler mingw-w64-x86_64-gtk3 mingw-w64-x86_64-gstreamer mingw-w64-x86_64-gst-plugins-base mingw-w64-x86_64-json-glib mingw-w64-x86_64-libsoup mingw-w64-x86_64-qrencode mingw-w64-x86_64-discount

(change `x86_64` to `i686` if you want to compile the 32-bit variant).

Downloading and compilation
---------------------------

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

Note: You may alter the final installation prefix in the cmake call. By default,
the pdfpc files will be installed under */usr/local/*. If you want to change
that, for example to be installed under */usr/*, you can specify another
installation prefix as follows::

    cmake -DCMAKE_INSTALL_PREFIX="/usr" ..

By default, pdfpc includes support for movie playback.  This requires several
gstreamer dependencies.  The requirement for these packages
can be removed by compiling without support for movie playback by passing
*-DMOVIES=OFF* to the cmake command.

To disable support for the built-in REST Web server, pass *-DREST=OFF* to cmake.
In this case, libsoup and libqrencode are not needed.

To disable support for viewing notes in the Markdown format, pass *-DMDVIEW=OFF*
to cmake. In this case, webkit2gtk is not needed. If webkit2gtk is not available
for your OS (i.e., macOS or Windows), you *must* pass this option for the build to succeed.

On Windows, the compilation has been tested with the Ninja backend, so pass *-DCMAKE_MAKE_PROGRAM=ninja* to the cmake command and use *ninja* instead of *make*.


Compilation troubleshooting
---------------------------

Some distributions do not have a *valac* executable. Instead they ship with a
version suffix like *valac-0.40*. If cmake cannot find the Vala compiler, you
can try running cmake with::

    cmake -DVALA_EXECUTABLE:NAMES=valac-0.40 ..

Acknowledgements
================

pdfpc was initially developed as pdfpc-presenter-console by Jakob Westhoff
(https://github.com/jakobwesthoff/Pdf-Presenter-Console)
then further extended by David Vilar (https://github.com/davvil/pdfpc).
