namespace Poppler {
    [CCode (cheader_filename = "poppler.h")]
    public class AnnotFileAttachment : Poppler.AnnotMarkup {
        [CCode (has_construct_function = false)]
        protected AnnotFileAttachment ();
        public unowned Poppler.Attachment get_attachment ();
        public unowned string get_name ();
    }
}
