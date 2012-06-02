using GLib;

using pdfpc;

namespace pdfpc {
    
    public class LinkAction: ActionMapping {
        
        public LinkAction(Poppler.LinkMapping mapping, PresentationController controller,
                Poppler.Document document) {
            base(mapping, controller, document);
        }
        
        public static ActionMapping? new_if_handled(Poppler.LinkMapping mapping,
                PresentationController controller, Poppler.Document document) {
            return new LinkAction(mapping, controller, document) as ActionMapping;
        }
        
        public override bool on_button_press(Gtk.Widget widget, Gdk.EventButton event) {
            if (event.button != 1)
                return false;
            
            switch( this.action.type ) {
                // Internal goto link
                case Poppler.ActionType.GOTO_DEST:
                    // There are different goto destination types we need to
                    // handle correctly.
                    unowned Poppler.ActionGotoDest* action = (Poppler.ActionGotoDest*)this.action;
                    switch( action.dest.type ) {
                        case Poppler.DestType.NAMED:
                            MutexLocks.poppler.lock();
#if VALA_0_16
                            Poppler.Dest destination;
#else
                            unowned Poppler.Dest destination;
#endif
                            destination = this.document.find_dest( 
                                action.dest.named_dest
                            );
                            MutexLocks.poppler.unlock();

                            // Fire the correct signal for this
                            this.controller.page_change_request((int)(destination.page_num - 1));
                        break;
                    }
                break;
                // External launch link
                /*case Poppler.ActionType.LAUNCH:
                    unowned Poppler.ActionLaunch* action = (Poppler.ActionLaunch*)mapping.action;
                    // Fire the appropriate signal
                    this.clicked_external_command( 
                        this.target.convert_poppler_rectangle_to_gdk_rectangle( mapping.area ),
                        mapping.area,
                        this.target.get_current_slide_number(),
                        action.file_name,
                        action.params
                    );
                break;*/
            }
        return true;
        }
    }
}
