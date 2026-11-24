using System.Runtime.InteropServices;

namespace AtscLauncher;

/// <summary>The kernel32 functions and constants the launcher calls.</summary>
internal static unsafe partial class Native
{
    internal const int StdInputHandle = -10;
    internal const int StdOutputHandle = -11;
    internal const int StdErrorHandle = -12;
    internal const nint InvalidHandleValue = -1;

    internal const uint StartfUseStdHandles = 0x100;
    internal const uint CreateSuspended = 0x4;
    internal const uint DetachedProcess = 0x8;
    internal const uint DuplicateSameAccess = 0x2;
    internal const uint Infinite = 0xFFFFFFFF;
    internal const uint WaitObject0 = 0;
    internal const uint CtrlCloseEvent = 2;

    internal const int JobObjectExtendedLimitInformationClass = 9;
    internal const uint JobObjectLimitSilentBreakawayOk = 0x1000;
    internal const uint JobObjectLimitKillOnJobClose = 0x2000;

    internal const uint GenericRead = 0x80000000;
    internal const uint GenericWrite = 0x40000000;
    internal const uint FileShareRead = 0x1;
    internal const uint FileShareWrite = 0x2;
    internal const uint OpenExisting = 3;

    [LibraryImport("kernel32.dll")]
    internal static partial char* GetCommandLineW();

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial uint GetLongPathNameW(char* shortPath, char* longPath, uint length);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial nint CreateJobObjectW(void* attributes, char* name);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int SetInformationJobObject(nint job, int infoClass, void* info, uint length);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int AssignProcessToJobObject(nint job, nint process);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int CloseHandle(nint handle);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial nint GetStdHandle(int which);

    [LibraryImport("kernel32.dll")]
    internal static partial nint GetCurrentProcess();

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int DuplicateHandle(
        nint sourceProcess,
        nint source,
        nint targetProcess,
        nint* target,
        uint access,
        int inherit,
        uint options);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial nint CreateFileW(
        char* name,
        uint access,
        uint share,
        void* security,
        uint disposition,
        uint flags,
        nint template);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int CreateProcessW(
        char* applicationName,
        char* commandLine,
        void* processAttributes,
        void* threadAttributes,
        int inheritHandles,
        uint creationFlags,
        void* environment,
        char* currentDirectory,
        StartupInfo* startupInfo,
        ProcessInformation* processInformation);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial uint ResumeThread(nint thread);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int TerminateProcess(nint process, uint exitCode);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial uint WaitForSingleObject(nint handle, uint milliseconds);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int GetExitCodeProcess(nint process, uint* exitCode);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int SetConsoleCtrlHandler(delegate* unmanaged<uint, int> handler, int add);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int GetConsoleMode(nint console, uint* mode);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int WriteConsoleW(nint console, char* buffer, uint length, uint* written, void* reserved);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial int WriteFile(nint file, byte* buffer, uint length, uint* written, void* overlapped);
}
