using System;

namespace AtscLauncher;

/// <summary>Decides which atsc.exe command line a launcher named after an atsc subcommand runs.</summary>
internal static class Launch
{
    /// <summary>The atsc subcommands a launcher may be named after.</summary>
    internal static readonly string[] Commands =
    {
        "at_activate",
        "noports",
        "np_admin",
        "npevents",
        "npp",
        "npp_atserver",
        "npp_file",
        "npt",
        "srvd",
        "sshnp",
        "sshnpd",
    };

    internal const string AtscFileName = "atsc.exe";

    /// <summary>The exit code for the launcher's own failures, the one the Unix launchers use.</summary>
    internal const int FailureExitCode = 127;

    private const int ErrorFileNotFound = 2;
    private const int ErrorPathNotFound = 3;

    /// <summary>
    /// Plans the child process for a launcher at <paramref name="modulePath"/> started with
    /// <paramref name="commandLine"/>, returning an error message, or null and the plan.
    /// </summary>
    internal static string? TryPlan(
        string? modulePath,
        string commandLine,
        out string command,
        out string atscPath,
        out string childCommandLine)
    {
        command = atscPath = childCommandLine = "";
        string? directory = modulePath == null ? null : DirectoryOf(modulePath);
        if (modulePath == null || directory == null)
        {
            return "cannot find the directory this NoPorts launcher runs from";
        }

        string name = NameFromPath(modulePath);
        if (Array.IndexOf(Commands, name) < 0)
        {
            return $"\"{name}\" is not a NoPorts command; this launcher must be named one of: "
                + string.Join(", ", Commands);
        }

        command = name;
        atscPath = directory + AtscFileName;
        childCommandLine = ChildCommandLine(atscPath, command, ArgumentTail(commandLine));
        return null;
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
        string head = "\"" + atscPath + "\" " + command;
        return tail.Length == 0 ? head : head + " " + tail;
    }

    /// <summary>Returns the message for CreateProcessW failing with <paramref name="error"/>.</summary>
    internal static string StartFailure(string command, string atscPath, int error)
    {
        return error == ErrorFileNotFound || error == ErrorPathNotFound
            ? $"{command}: cannot find {atscPath}; NoPorts needs {AtscFileName} beside {command}.exe"
            : $"{command}: cannot start {atscPath} (Windows error {error})";
    }
}
