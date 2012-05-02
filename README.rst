=====================
Pdf Presenter Console
=====================

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
at http://davvil.github.com/pdfpc/

Requirements
============

In order to compile and run the Pdf Presenter Console the following
requirements need to be met:

- Vala Compiler Version >=0.16.0
- CMake Version >=2.6
- Gtk+ 2.x
- libPoppler with glib bindings
- librsvg

Compile and install
===================

Currently pdfpc is only available through github. The master branch should be
mostly stable.  If the git executable is available on your system it can be
retrieved using the following command::

    git clone git://github.com/davvil/pdfpc.git

After it has been transfered you need to switch to the ``pdfpc`` directory,
which has just been created. From inside this directory use these commands to
retrieve all needed submodules::

    git submodule init
    git submodule update

You are now set to compile and install pdfpc.  Start by creating a build
directory::

    mkdir build
    cd build

After you are inside the build directory create the needed Makefiles using
CMake::

    cmake ../

If you have put your build directory elsewhere on your system adapt the path
above accordingly. You need to provide CMake with the pdfpc directory as
created by git.

You may alter the final installation prefix at this time. By default the
pdfpc executable will be installed under */usr/local/bin*. If
you want to change that, for example to be */usr/bin* you may specify another
installation prefix as follows::

    cmake -DCMAKE_INSTALL_PREFIX="/usr" ../

If all requirements are met CMake will tell you that it created all the
necessary build files for you. If any of the requirements were not met you
will be informed of it to provide the necessary files or install the
appropriate packages.

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

Head over to http://davvil.github.com/pdfpc and download the demo presentation.
Load it into pdfpc to get a feeling of it::

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
