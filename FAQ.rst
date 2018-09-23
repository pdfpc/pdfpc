===
FAQ
===

Scaling issues with Wayland
===========================

If you encounter wrong scaling of PDFs within the presenter and presentation
window, you can try the::

    --wayland-workaround

flag. See issue #312 and #214 for more information.

Embedded video playback is not working.
=======================================

You likely have a ``gstreamer`` codec issue. Try loading the video file you
want to play with the following command: ``gst-launch-1.0 filesrc
location=<your video> ! decodebin !  autovideosink``  If the video plays, go
ahead and `submit an issue <https://github.com/pdfpc/pdfpc/issues>`_.
Otherwise, the command will likely output some good hints for why gstreamer
cannot decode the video.

Windows do not appear on the correct screen.
============================================

For tiling window managers, the movement and fullscreening of the windows do not work reliable.
It is therefore important to tell your WM to force floating the pdfpc windows.

If you are using i3-wm add this to your config file::

    for_window [ title="^pdfpc - present" ] border none floating enable

