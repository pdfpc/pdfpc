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
at http://davvil.github.com/pdfpc/

Requirements
============

In order to compile and run pdfpc the following
requirements need to be met:

- CMake Version >=2.6
- Gtk+ 2.x
- libPoppler with glib bindings
- librsvg

Compile and install
===================

Compiling from source tarballs
------------------------------

You can download the latest stable release of pdfpc in the download section of
github (https://github.com/davvil/pdfpc/downloads). Uncompress the tarball (we
use v3.0 as an example here)::

    tar xvf pdfpc-3.0.tgz

Change to the extracted directory::

    cd pdfpc-3.0

Compile and install::

    cmake .
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

    cmake -DCMAKE_INSTALL_PREFIX="/usr" -DSYSCONFDIR=/etc .

Compiling from github
---------------------

If you want the bleeding-edge version of pdfpc, you should checkout the git
repository. The *master* branch should be fairly stable and safe to use,
unstable development happens in the *devel* branch.

When installing from git you will need two additional dependencies:

- git
- Vala Compiler Version >=0.16.0

The pdfpc source can be retrieved from github::

    git clone git://github.com/davvil/pdfpc.git

After it has been transfered you need to switch to the ``pdfpc`` directory,
which has just been created. From inside this directory use these commands to
retrieve all needed submodules::

    git submodule init
    git submodule update

You are now set to compile and install pdfpc.  Start by creating a build
directory (this is optional but it keeps the directories clean, in case you
want to do some changes)::

    mkdir build
    cd build

After you are inside the build directory create the needed Makefiles using
CMake::

    cmake ../

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
    make install

You may need to prefix the last command with a *sudo* or obtain super-user
rights in any other way applicable to your situation.

Congratulations you just installed pdfpc on your system.

How to go on
============

Download the demo presentation from the downloads section and load it into
pdfpc to get a feeling of it::

    pdfpc pdfpc-demo.pdf

Acknowledgements
================

pdfpc is a  fork  of  pdf-presenter  console,  available  at
http://westhoffswelt.de/projects/pdf_presenter_console.html


..
   Local Variables:
   mode: rst
   fill-column: 79
   End: 
   vim: et syn=rst tw=79
