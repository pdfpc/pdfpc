using GLib;

using pdfpc;

namespace pdfpc {
    
    public class LinkAction: ActionMapping {
        
        public Poppler.Action action;
        
        public LinkAction() {
            base();
        }
        
        public new void init(Poppler.LinkMapping mapping, PresentationController controller,
                Poppler.Document document) {
            base.init(mapping.area, controller, document);
            this.action = mapping.action.copy();
        }
        
        public override ActionMapping? new_from_link_mapping(Poppler.LinkMapping mapping,
                PresentationController controller, Poppler.Document document) {
            if (mapping.action.type != Poppler.ActionType.GOTO_DEST)
                return null;
            if (((Poppler.ActionGotoDest*)mapping.action).dest.type != Poppler.DestType.NAMED)
                return null;
            
            var new_obj = new LinkAction();
            new_obj.init(mapping, controller, document);
            return new_obj as ActionMapping;
        }
        
        public override bool on_button_press(Gtk.Widget widget, Gdk.EventButton event) {
            if (event.button != 1)
                return false;
            
            unowned Poppler.ActionGotoDest* action = (Poppler.ActionGotoDest*)this.action;
            MutexLocks.poppler.lock();
#if VALA_0_16
            Poppler.Dest destination;
#else
            unowned Poppler.Dest destination;
#endif
            destination = this.document.find_dest(action.dest.named_dest);
            MutexLocks.poppler.unlock();
            
            this.controller.page_change_request((int)(destination.page_num - 1));
            return true;
        }
    }
}
