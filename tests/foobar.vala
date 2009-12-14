using org.westhoffswelt.pdfpresenter;
namespace org.westhoffswelt.pdfpresenter.tests {
    public static void main( string[] args ) {
        Gtk.init( ref args );
        Test.init( ref args );

        Test.add_func( "/foobar/sometest", () => {
            assert( "foo" != "bar" );
        });
           
        Idle.add( () => {
            Test.run();
            Gtk.main_quit ();
        });
       
       Gtk.main();
    }
}
