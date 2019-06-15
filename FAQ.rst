===
FAQ
===

Scaling issues with Wayland
===========================

If you encounter wrong scaling of PDFs within the presenter and presentation
window, you can try the::

    --wayland-workaround

flag. See issues #312 and #214 for more information.

Video playback is not working
=============================

You likely have a ``gstreamer`` codec issue. In particular,
pdfpc uses the "gtksink" ``gstreamer`` plugin. On modern Debian-based systems,
it is part of the ``gstreamer1.0-gtk3`` package; install it with::

    sudo apt-get install gstreamer1.0-gtk3

Try loading the video file you want to play with the following command:
``gst-play-1.0 --videosink gtksink <your video>``.
If the video plays with no errors or warnings, go ahead and `submit an issue
<https://github.com/pdfpc/pdfpc/issues>`_. Otherwise, the command will likely
output some good hints for why gstreamer cannot decode the video.

Windows do not appear on the correct screen
===========================================

For tiling window managers, the movement and fullscreening of the windows do not
work reliably. It is therefore important to tell your WM to force floating the
pdfpc windows.

If you are using i3-wm add this to your config file::

    for_window [ title="^pdfpc - present" ] border none floating enable

