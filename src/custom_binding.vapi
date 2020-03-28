[CCode (cheader_filename = "display_backend.h")]
namespace Pdfpc {
    [CCode (cname = "is_Wayland_backend")]
    bool is_Wayland_backend();

    [CCode (cname = "is_X11_backend")]
    bool is_X11_backend();

    [CCode (cname = "is_Quartz_backend")]
    bool is_Quartz_backend();
}
