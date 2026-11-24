using System;
using System.IO;

namespace AtscLauncher;

/// <summary>The steps that let a child created suspended run inside the launcher's job.</summary>
internal interface ISuspendedChild
{
    /// <summary>Puts the child in the launcher's job, or gives the Windows error.</summary>
    bool TryJoinJob(out int error);

    /// <summary>Lets the child's thread run, or gives the Windows error.</summary>
    bool TryResume(out int error);

    /// <summary>Ends the child with <paramref name="exitCode"/>.</summary>
    void Terminate(int exitCode);
}

/// <summary>Decides the atsc.exe command line a launcher runs: its own name, then its arguments.</summary>
internal static class Launch
{
    internal const string AtscFileName = "atsc.exe";

    /// <summary>The exit code for the launcher's own failures, the one the Unix launchers use.</summary>
    internal const int FailureExitCode = 127;

    private const int ErrorFileNotFound = 2;
    private const int ErrorPathNotFound = 3;

    /// <summary>
    /// Plans the child process for a launcher started as <paramref name="startedPath"/> with
    /// <paramref name="commandLine"/>, whose file is <paramref name="finalPath"/> once links are
    /// followed, returning an error message, or null and the plan.
    /// </summary>
    internal static string? TryPlan(
        string? startedPath,
        string? finalPath,
        string commandLine,
        out string command,
        out string atscPath,
        out string childCommandLine)
    {
        command = atscPath = childCommandLine = "";
        string? directory = finalPath == null ? null : DirectoryOf(finalPath);
        if (startedPath == null || DirectoryOf(startedPath) == null || directory == null)
        {
            return "cannot find the directory this NoPorts launcher runs from";
        }

        string name = NameFromPath(startedPath);
        if (name == "atsc")
        {
            return $"a launcher named {AtscFileName} would run itself; name it after a NoPorts program";
        }

        command = name;
        atscPath = directory + AtscFileName;
        childCommandLine = ChildCommandLine(atscPath, command, ArgumentTail(commandLine));
        return null;
    }

    /// <summary>
    /// Returns the file <paramref name="path"/> names once symbolic links to it are followed:
    /// <paramref name="path"/> itself when it is no link, or null when it is unknown or its links
    /// cannot be followed.
    /// </summary>
    internal static string? FinalPath(string? path)
    {
        if (path == null)
        {
            return null;
        }

        try
        {
            return File.ResolveLinkTarget(path, returnFinalTarget: true)?.FullName ?? path;
        }
        catch (IOException)
        {
            return null;
        }
        catch (UnauthorizedAccessException)
        {
            return null;
        }
    }

    /// <summary>Returns the file name of <paramref name="path"/>, ASCII-lower-cased, without a trailing ".exe".</summary>
    internal static string NameFromPath(string path)
    {
        string name = path.Substring(path.LastIndexOfAny(new[] { '\\', '/' }) + 1);
        var folded = new char[name.Length];
        for (int i = 0; i < name.Length; i++)
        {
            char c = name[i];
            folded[i] = c >= 'A' && c <= 'Z' ? (char)(c + ('a' - 'A')) : c;
        }

        string lower = new string(folded);
        return lower.EndsWith(".exe", StringComparison.Ordinal) ? lower.Substring(0, lower.Length - 4) : lower;
    }

    /// <summary>
    /// Returns the directory of <paramref name="path"/> ending in its separator, or null when
    /// the path is not absolute (a drive letter and root, or a leading double backslash).
    /// </summary>
    internal static string? DirectoryOf(string path)
    {
        int last = path.LastIndexOfAny(new[] { '\\', '/' });
        if (last < 0)
        {
            return null;
        }

        string directory = path.Substring(0, last + 1);
        bool driveRoot = directory.Length >= 3
            && char.IsAsciiLetter(directory[0])
            && directory[1] == ':'
            && (directory[2] == '\\' || directory[2] == '/');
        bool unc = directory.StartsWith(@"\\", StringComparison.Ordinal);
        return driveRoot || unc ? directory : null;
    }

    /// <summary>
    /// Returns the arguments of a Windows command line unchanged: everything after the program
    /// name as CommandLineToArgvW delimits it, less the spaces and tabs before the first argument.
    /// </summary>
    internal static string ArgumentTail(string commandLine)
    {
        int i;
        if (commandLine.Length > 0 && commandLine[0] == '"')
        {
            int close = commandLine.IndexOf('"', 1);
            i = close < 0 ? commandLine.Length : close + 1;
        }
        else
        {
            i = 0;
            while (i < commandLine.Length && commandLine[i] != ' ' && commandLine[i] != '\t')
            {
                i++;
            }
        }

        while (i < commandLine.Length && (commandLine[i] == ' ' || commandLine[i] == '\t'))
        {
            i++;
        }

        return commandLine.Substring(i);
    }

    /// <summary>Builds the command line that runs atsc at <paramref name="atscPath"/> as <paramref name="command"/> with <paramref name="tail"/>.</summary>
    internal static string ChildCommandLine(string atscPath, string command, string tail)
    {
        // NOTE: a Windows file name holds no double quote, so quoting needs no escapes.
        bool quote = command.Length == 0 || command.IndexOfAny(new[] { ' ', '\t' }) >= 0;
        string head = "\"" + atscPath + "\" " + (quote ? "\"" + command + "\"" : command);
        return tail.Length == 0 ? head : head + " " + tail;
    }

    /// <summary>
    /// Lets <paramref name="child"/>, created suspended, run only once it is in the launcher's job;
    /// ends it and returns the message when it cannot, or returns null.
    /// </summary>
    internal static string? Release(ISuspendedChild child, string command, string atscPath)
    {
        if (!child.TryJoinJob(out int error))
        {
            child.Terminate(FailureExitCode);
            return JobFailure(command, atscPath, error);
        }

        if (!child.TryResume(out error))
        {
            child.Terminate(FailureExitCode);
            return $"{command}: cannot resume {atscPath} (Windows error {error})";
        }

        return null;
    }

    /// <summary>Returns the message for failing to run atsc in a job that ends it with the launcher.</summary>
    internal static string JobFailure(string command, string atscPath, int error)
    {
        return $"{command}: cannot run {atscPath} in a job that ends it with this launcher (Windows error {error})";
    }

    /// <summary>Returns the message for CreateProcessW failing with <paramref name="error"/>.</summary>
    internal static string StartFailure(string command, string atscPath, int error)
    {
        return error == ErrorFileNotFound || error == ErrorPathNotFound
            ? $"{command}: cannot find {atscPath}; NoPorts needs {AtscFileName} beside {command}.exe"
            : $"{command}: cannot start {atscPath} (Windows error {error})";
    }
}
