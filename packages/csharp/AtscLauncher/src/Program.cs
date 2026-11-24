using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace AtscLauncher;

/// <summary>Runs atsc.exe from the launcher's own directory as the subcommand the launcher is named after.</summary>
internal static unsafe class Program
{
    private static nint s_child;

    private static int Main()
    {
        string commandLine = new string(Native.GetCommandLineW());
        string? startedPath = LongPath(Environment.ProcessPath);
        string? error = Launch.TryPlan(
            startedPath,
            Launch.FinalPath(startedPath),
            commandLine,
            out string command,
            out string atscPath,
            out string childCommandLine);
        if (error != null)
        {
            WriteError(error);
            return Launch.FailureExitCode;
        }

        return Run(command, atscPath, childCommandLine);
    }

    private static int Run(string command, string atscPath, string childCommandLine)
    {
        Native.SetConsoleCtrlHandler(&OnConsoleControl, 1);
        nint job = CreateKillOnCloseJob(out int jobError);
        if (job == 0)
        {
            WriteError(Launch.JobFailure(command, atscPath, jobError));
            return Launch.FailureExitCode;
        }

        StartupInfo startupInfo = default;
        startupInfo.Cb = (uint)sizeof(StartupInfo);
        startupInfo.Flags = Native.StartfUseStdHandles;
        startupInfo.StdInput = InheritableCopy(Native.StdInputHandle);
        startupInfo.StdOutput = InheritableCopy(Native.StdOutputHandle);
        startupInfo.StdError = InheritableCopy(Native.StdErrorHandle);
        // NOTE: atsc starts suspended, and runs only once it is in the job.
        uint flags = Native.CreateSuspended | (HasConsole() ? 0 : Native.DetachedProcess);

        ProcessInformation child;
        char[] mutableCommandLine = (childCommandLine + "\0").ToCharArray();
        int started;
        int startError;
        fixed (char* application = atscPath)
        fixed (char* line = mutableCommandLine)
        {
            // NOTE: lpApplicationName is the full path, so CreateProcessW never searches for atsc.exe.
            started = Native.CreateProcessW(application, line, null, null, 1, flags, null, null, &startupInfo, &child);
            startError = Marshal.GetLastPInvokeError();
        }

        CloseCopy(startupInfo.StdInput, Native.StdInputHandle);
        CloseCopy(startupInfo.StdOutput, Native.StdOutputHandle);
        CloseCopy(startupInfo.StdError, Native.StdErrorHandle);
        if (started == 0)
        {
            WriteError(Launch.StartFailure(command, atscPath, startError));
            return Launch.FailureExitCode;
        }

        Volatile.Write(ref s_child, child.Process);
        string? releaseError = Launch.Release(new SuspendedChild(job, child), command, atscPath);
        Native.CloseHandle(child.Thread);
        if (releaseError != null)
        {
            WriteError(releaseError);
            return Launch.FailureExitCode;
        }

        uint exitCode;
        if (Native.WaitForSingleObject(child.Process, Native.Infinite) != Native.WaitObject0
            || Native.GetExitCodeProcess(child.Process, &exitCode) == 0)
        {
            WriteError($"{command}: lost track of {atscPath} (Windows error {Marshal.GetLastPInvokeError()})");
            return Launch.FailureExitCode;
        }

        return unchecked((int)exitCode);
    }

    // NOTE: the job is a raw handle kept open until exit, never a SafeHandle: closing it kills atsc.
    private static nint CreateKillOnCloseJob(out int error)
    {
        nint job = Native.CreateJobObjectW(null, null);
        if (job == 0)
        {
            error = Marshal.GetLastPInvokeError();
            return 0;
        }

        JobExtendedLimitInformation limits = default;
        // NOTE: SILENT_BREAKAWAY_OK keeps processes atsc starts, such as srv, out of the job, so closing it ends atsc alone.
        limits.LimitFlags = Native.JobObjectLimitKillOnJobClose | Native.JobObjectLimitSilentBreakawayOk;
        if (Native.SetInformationJobObject(
                job,
                Native.JobObjectExtendedLimitInformationClass,
                &limits,
                (uint)sizeof(JobExtendedLimitInformation)) == 0)
        {
            error = Marshal.GetLastPInvokeError();
            Native.CloseHandle(job);
            return 0;
        }

        error = 0;
        return job;
    }

    /// <summary>A child created suspended, with the job it is to run in.</summary>
    private sealed class SuspendedChild : ISuspendedChild
    {
        private readonly nint _job;
        private readonly ProcessInformation _child;

        internal SuspendedChild(nint job, ProcessInformation child)
        {
            _job = job;
            _child = child;
        }

        public bool TryJoinJob(out int error)
        {
            bool joined = Native.AssignProcessToJobObject(_job, _child.Process) != 0;
            error = joined ? 0 : Marshal.GetLastPInvokeError();
            return joined;
        }

        public bool TryResume(out int error)
        {
            bool resumed = Native.ResumeThread(_child.Thread) != uint.MaxValue;
            error = resumed ? 0 : Marshal.GetLastPInvokeError();
            return resumed;
        }

        public void Terminate(int exitCode)
        {
            Native.TerminateProcess(_child.Process, unchecked((uint)exitCode));
        }
    }

    private static nint InheritableCopy(int which)
    {
        nint handle = Native.GetStdHandle(which);
        // NOTE: INVALID_HANDLE_VALUE is also the current-process pseudo-handle, so it is never duplicated.
        if (handle == 0 || handle == Native.InvalidHandleValue)
        {
            return handle;
        }

        nint process = Native.GetCurrentProcess();
        nint copy;
        return Native.DuplicateHandle(process, handle, process, &copy, 0, 1, Native.DuplicateSameAccess) != 0
            ? copy
            : handle;
    }

    private static void CloseCopy(nint copy, int which)
    {
        if (copy != Native.GetStdHandle(which))
        {
            Native.CloseHandle(copy);
        }
    }

    private static bool HasConsole()
    {
        fixed (char* name = "CONOUT$")
        {
            nint console = Native.CreateFileW(
                name,
                Native.GenericRead | Native.GenericWrite,
                Native.FileShareWrite,
                null,
                Native.OpenExisting,
                0,
                0);
            if (console == Native.InvalidHandleValue)
            {
                return false;
            }

            Native.CloseHandle(console);
            return true;
        }
    }

    private static string? LongPath(string? path)
    {
        if (path == null)
        {
            return null;
        }

        const uint capacity = 32768;
        char[] buffer = new char[capacity];
        fixed (char* shortPath = path)
        fixed (char* longPath = buffer)
        {
            uint length = Native.GetLongPathNameW(shortPath, longPath, capacity);
            return length == 0 || length >= capacity ? path : new string(longPath, 0, (int)length);
        }
    }

    // NOTE: a handler, never SetConsoleCtrlHandler(NULL, TRUE), whose ignore flag atsc would inherit.
    [UnmanagedCallersOnly]
    private static int OnConsoleControl(uint controlType)
    {
        nint child = Volatile.Read(ref s_child);
        if (controlType >= Native.CtrlCloseEvent && child != 0)
        {
            Native.WaitForSingleObject(child, Native.Infinite);
        }

        return 1;
    }

    private static void WriteError(string message)
    {
        nint stderr = Native.GetStdHandle(Native.StdErrorHandle);
        if (stderr == 0 || stderr == Native.InvalidHandleValue)
        {
            return;
        }

        string text = message + "\r\n";
        uint mode;
        uint written;
        if (Native.GetConsoleMode(stderr, &mode) != 0)
        {
            fixed (char* chars = text)
            {
                Native.WriteConsoleW(stderr, chars, (uint)text.Length, &written, null);
            }

            return;
        }

        byte[] bytes = Encoding.UTF8.GetBytes(text);
        fixed (byte* data = bytes)
        {
            Native.WriteFile(stderr, data, (uint)bytes.Length, &written, null);
        }
    }
}
