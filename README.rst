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

Requirements
============

In order to compile and run pdfpc the following
requirements need to be met:

- CMake Version >=2.6
- valac >= 0.26
- GTK+ >= 3.10
- gee 0.8
- poppler with glib bindings
- gstreamer 1.0

Compile and install
===================

Compiling from source tarballs
------------------------------

You can download the latest stable release of pdfpc in the release section of
github (https://github.com/pdfpc/pdfpc/releases). Uncompress the tarball (we
use v4.0 as an example here)::

    tar xvf pdfpc-4.0.tar.gz

Change to the extracted directory::

    cd pdfpc-4.0

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

Compiling from github
---------------------

If you want the bleeding-edge version of pdfpc, you should checkout the git
repository. The *master* branch should be fairly stable and safe to use.

The pdfpc source can be retrieved from github::

    git clone --recursive git://github.com/pdfpc/pdfpc.git

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

How to go on
============

Download the demo presentation from the downloads section and load it into
pdfpc to get a feeling of it::

    pdfpc pdfpc-demo.pdf

Acknowledgements
================

pdfpc has been developed by Jakob Westhoff, David Vilar, Robert Schroll, Andreas
Bilke, Andy Barry, and others.  It was previously available at
https://github.com/davvil/pdfpc

pdfpc is a fork of Pdf Presenter Console by Jakob Westhoff, available at
https://github.com/jakobwesthoff/Pdf-Presenter-Console


..
   Local Variables:
   mode: rst
   fill-column: 79
   End: 
   vim: et syn=rst tw=79
