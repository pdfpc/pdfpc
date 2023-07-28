namespace pdfpc {
    public class ResourceLocator {
        /**
         * Finds a path to a given resource
         *
         * Returns the path of the file or null if it wasn't found
         */
         public static string? getResourcePath(string resource) {
            var shareSuffix  = "share/pdfpc";
 
            char[] pathBuf = new char[ProcInfo.MAX_PATH_LENTH];
            ProcInfo.GetProcessPath(ref pathBuf);
            string appPath = (string) pathBuf;

            var start = File.new_for_path(appPath).get_parent();
            for (var i = 0; i < 3; ++i, start = start.get_parent()) {
                {
                    var file = start.resolve_relative_path(resource);
                    if (file.query_exists()) {
                            return file.get_path();
                    }
                }
                {
                    var file = start.resolve_relative_path(shareSuffix).resolve_relative_path(resource);
                    if (file.query_exists()) {
                            return file.get_path();
                    }
                }           
            }

            return null;
        }
    }
}