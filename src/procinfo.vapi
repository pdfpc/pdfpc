[CCode (cheader_filename = "procinfo.h")]
namespace ProcInfo {
    [CCode (cname = "MAX_PATH_LENTH")]
    public const int MAX_PATH_LENTH;

    [CCode (cname = "GetProcessPath")]
    public void GetProcessPath(ref char[] path);
}
