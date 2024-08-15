===
FAQ
===

Scaling issues with Wayland
===========================

If you encounter wrong scaling of PDFs within the presenter and presentation
window, you can try the ``--wayland-workaround`` flag. See issues #312 and #214
for more information.

Video playback is not working
=============================

You likely have a ``gstreamer`` issue. In particular,
pdfpc uses the "gtksink" ``gstreamer`` plugin. On modern Debian-based systems,
it is part of the ``gstreamer1.0-gtk3`` package; install it with::

    sudo apt-get install gstreamer1.0-gtk3
    
On Arch Linux and derived (e.g., Manjaro) distributions, install it with::

    sudo pacman -S gst-plugin-gtk

Try loading the video file you want to play with the following command::

    gst-play-1.0 --gst-fatal-warnings --videosink gtksink <your video>

If ``gst-play-1.0`` is not found, you may need to install a package that
provides it, e.g., ``gstreamer1.0-plugins-base-apps``.

If the video plays with no errors or warnings, go ahead and `submit an issue
<https://github.com/pdfpc/pdfpc/issues>`_. Otherwise, the command will likely
output some hints on why gstreamer cannot play the video.

Windows do not appear on the correct screen
===========================================

For tiling window managers, the movement and fullscreening of the windows do not
work reliably. It is therefore important to tell your WM to force floating the
pdfpc windows.

If you are using i3-wm add this to your config file::

    for_window [ title="^pdfpc - present" ] border none floating enable

No presenter view showing (Mac workaround)
===========================================

Current for Sonoma 14.5, updated 8/14/24.

If no presenter view is showing, or if the presenter view flashes briefly then
disappears, you likely have the Mac option "prefer tabs when opening documents"
set to "always":

    "system settings > desktop and dock > prefer tabs when opening documents" set to always

This option forces pdfpc to open the presentation view as a second tab, the window is then
maximized and the tabs are no longer visible. 

Change this system setting to "never" on Mac to restore the expected behavior from pdfpc.

    "system settings > desktop and dock > prefer tabs when opening documents" set to never

An alternative to this, and potentially other window tiling managers, is to launch
pdfpc in a dimensioned window such as::

    pdfpc -Z 1000:1000 presentation.pdf

In this way we can see the tabs for presentation and presenter views, and manually drag them
to the screens we desire.