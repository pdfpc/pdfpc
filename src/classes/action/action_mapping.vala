using GLib;

using pdfpc;

namespace pdfpc {
    
    public abstract class ActionMapping: GLib.Object {
        // Looks like LinkMapping, but apparently we can't extend that
        
        public Poppler.Rectangle area;
        protected PresentationController controller;
        protected Poppler.Document document;
        
        public ActionMapping() {
            base();
        }
        
        public virtual void init(Poppler.Rectangle area, PresentationController controller,
                Poppler.Document document) {
            this.area = area;
            this.controller = controller;
            this.document = document;
        }
        
        public virtual ActionMapping? new_from_link_mapping(Poppler.LinkMapping mapping,
                PresentationController controller, Poppler.Document document) {
            return null;
        }
        
        public virtual ActionMapping? new_from_annot_mapping(Poppler.AnnotMapping mapping,
                PresentationController controller, Poppler.Document document) {
            return null;
        }
        
        public virtual void on_mouse_enter(Gtk.Widget widget, Gdk.EventMotion event) {
            // Set the cursor to the X11 theme default link cursor
            event.window.set_cursor(
                new Gdk.Cursor.from_name(Gdk.Display.get_default(), "hand2")
            );
        }
        
        public virtual void on_mouse_leave(Gtk.Widget widget, Gdk.EventMotion event) {
            // Restore the cursor to its default state (The parent cursor
            // configuration is used)
            event.window.set_cursor(null);
        }
        
        public abstract bool on_button_press(Gtk.Widget widget, Gdk.EventButton event);
        
        public virtual void deactivate() {
            return;
        }
    }
}
