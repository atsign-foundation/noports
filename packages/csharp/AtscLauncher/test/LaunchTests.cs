using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using Xunit;

namespace AtscLauncher.Tests;

/// <summary>Tests for how a launcher names its subcommand, finds atsc.exe and passes its arguments on.</summary>
public class LaunchTests
{
    private const string NptPath = @"C:\Program Files\NoPorts\npt.exe";
    private const string AtscPath = @"C:\Program Files\NoPorts\atsc.exe";

    /// <summary>Replaces each backtick with a double quote, so that command lines read as typed.</summary>
    private static string Q(string s) => s.Replace('`', '"');

    [Theory]
    [InlineData(@"C:\Program Files\NoPorts\npt.exe", "npt")]
    [InlineData(@"C:\Program Files\NoPorts\NPT.EXE", "npt")]
    [InlineData(@"C:\NoPorts\SshNpd.Exe", "sshnpd")]
    [InlineData(@"\\?\C:\NoPorts\npp_atserver.exe", "npp_atserver")]
    [InlineData(@"\\server\share\at_activate.exe", "at_activate")]
    [InlineData("C:/NoPorts/npt.exe", "npt")]
    [InlineData(@"C:\NoPorts\npt", "npt")]
    [InlineData(@"C:\NoPorts\npt.exe.exe", "npt.exe")]
    [InlineData(@"C:\No.exe\npt.cmd", "npt.cmd")]
    [InlineData("C:\\NoPorts\\AT_ACT\u0130VATE.EXE", "at_act\u0130vate")]
    [InlineData("C:\\NoPorts\\\u212A.exe", "\u212A")]
    public void TheNameIsTheFileNameAsciiLowerCasedWithoutExe(string path, string name)
    {
        Assert.Equal(name, Launch.NameFromPath(path));
    }

    [Theory]
    [InlineData(@"C:\NoPorts\atsc.exe")]
    [InlineData(@"C:\NoPorts\ATSC.EXE")]
    [InlineData(@"C:\NoPorts\atsc")]
    public void ALauncherNamedAtscRefusesToRun(string modulePath)
    {
        string? error = Launch.TryPlan(modulePath, modulePath, "atsc -d y", out _, out string atscPath, out string child);

        Assert.Equal("a launcher named atsc.exe would run itself; name it after a NoPorts program", error);
        Assert.Equal("", atscPath);
        Assert.Equal("", child);
    }

    [Theory]
    [InlineData("npt.exe", "npt")]
    [InlineData("srvd.exe", "srvd")]
    [InlineData("srv.exe", "srv")]
    [InlineData("sshnpdService.exe", "sshnpdservice")]
    [InlineData("npt2.exe", "npt2")]
    [InlineData("my npt.exe", "my npt")]
    [InlineData("npt\t.exe", "npt\t")]
    [InlineData(".exe", "")]
    [InlineData("--help.exe", "--help")]
    [InlineData("at_act\u0130vate.exe", "at_act\u0130vate")]
    [InlineData("\uFF4E\uFF50\uFF54.exe", "\uFF4E\uFF50\uFF54")]
    public void AnyOtherNameReachesAtscAsItsFirstArgument(string fileName, string name)
    {
        string path = @"C:\Program Files\NoPorts\" + fileName;

        string? error = Launch.TryPlan(path, path, Q("x -d `my device`"), out string command, out string atscPath, out string child);

        Assert.Null(error);
        Assert.Equal(name, command);
        Assert.Equal(AtscPath, atscPath);
        Assert.Equal(new[] { AtscPath, name, "-d", "my device" }, WindowsArgv.Split(child));
    }

    [Theory]
    [InlineData(@"C:\Program Files\NoPorts\npt.exe", @"C:\Program Files\NoPorts\")]
    [InlineData(@"C:\npt.exe", @"C:\")]
    [InlineData("c:/NoPorts/npt.exe", "c:/NoPorts/")]
    [InlineData(@"\\?\C:\NoPorts\npt.exe", @"\\?\C:\NoPorts\")]
    [InlineData(@"\\server\share\NoPorts\npt.exe", @"\\server\share\NoPorts\")]
    public void TheDirectoryOfAnAbsolutePathEndsInItsSeparator(string path, string directory)
    {
        Assert.Equal(directory, Launch.DirectoryOf(path));
    }

    [Theory]
    [InlineData("npt.exe")]
    [InlineData(@".\npt.exe")]
    [InlineData(@"NoPorts\npt.exe")]
    [InlineData(@"\NoPorts\npt.exe")]
    [InlineData("C:npt.exe")]
    [InlineData(@"C:NoPorts\npt.exe")]
    [InlineData("")]
    public void ARelativePathIsRefusedSoAtscIsNeverTakenFromTheCurrentDirectory(string modulePath)
    {
        Assert.Null(Launch.DirectoryOf(modulePath));
        string? error = Launch.TryPlan(modulePath, modulePath, "npt -d x", out _, out string atscPath, out _);
        Assert.Equal("cannot find the directory this NoPorts launcher runs from", error);
        Assert.Equal("", atscPath);
    }

    [Fact]
    public void ALinkedLauncherRunsTheAtscInTheInstallationItLinksTo()
    {
        string? error = Launch.TryPlan(
            @"C:\Users\me\bin\npt.exe", NptPath, "npt -d x", out string command, out string atscPath, out string child);

        Assert.Null(error);
        Assert.Equal("npt", command);
        Assert.Equal(AtscPath, atscPath);
        Assert.Equal(Q($"`{AtscPath}` npt -d x"), child);
    }

    [Theory]
    [InlineData(@"C:\Users\me\bin\npt.exe", null)]
    [InlineData(@"C:\Users\me\bin\npt.exe", @"NoPorts\npt.exe")]
    [InlineData(@"bin\npt.exe", NptPath)]
    public void ALauncherIsRefusedUnlessBothItsPathsAreAbsolute(string startedPath, string? finalPath)
    {
        string? error = Launch.TryPlan(startedPath, finalPath, "npt -d x", out _, out string atscPath, out _);

        Assert.Equal("cannot find the directory this NoPorts launcher runs from", error);
        Assert.Equal("", atscPath);
    }

    [Fact]
    public void FollowingLinksFindsTheFileTheyFinallyName()
    {
        string root = Directory.CreateTempSubdirectory("atsc-launcher-").FullName;
        try
        {
            string install = Directory.CreateDirectory(Path.Join(root, "NoPorts")).FullName;
            string bin = Directory.CreateDirectory(Path.Join(root, "bin")).FullName;
            string npt = Path.Join(install, "npt.exe");
            File.WriteAllText(npt, "");
            string relativeLink = Path.Join(bin, "npt.exe");
            File.CreateSymbolicLink(relativeLink, Path.Join("..", "NoPorts", "npt.exe"));
            string linkToLink = Path.Join(root, "npt.exe");
            File.CreateSymbolicLink(linkToLink, relativeLink);

            Assert.Equal(npt, Launch.FinalPath(npt));
            Assert.Equal(npt, Launch.FinalPath(relativeLink));
            Assert.Equal(npt, Launch.FinalPath(linkToLink));
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public void LinksThatCannotBeFollowedGiveNoPath()
    {
        string root = Directory.CreateTempSubdirectory("atsc-launcher-").FullName;
        try
        {
            string a = Path.Join(root, "a.exe");
            string b = Path.Join(root, "b.exe");
            File.CreateSymbolicLink(a, b);
            File.CreateSymbolicLink(b, a);

            Assert.Null(Launch.FinalPath(a));
            Assert.Null(Launch.FinalPath(null));
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public void AnUnknownModulePathIsRefused()
    {
        Assert.Equal(
            "cannot find the directory this NoPorts launcher runs from",
            Launch.TryPlan(null, null, "npt -d x", out _, out _, out _));
    }

    [Theory]
    [InlineData(@"`C:\Program Files\NoPorts\npt.exe` -d `my device` `` --key=`a b` -", @"-d `my device` `` --key=`a b` -")]
    [InlineData(@"C:\NoPorts\npt.exe -d `my device` `` --key=`a b` -", @"-d `my device` `` --key=`a b` -")]
    [InlineData("npt.exe\t-d\tx", "-d\tx")]
    [InlineData("npt.exe \t  -d", "-d")]
    [InlineData("npt.exe -d  x  ", "-d  x  ")]
    [InlineData(@"`C:\Program Files\NoPorts\npt.exe`", "")]
    [InlineData("npt.exe", "")]
    [InlineData("npt.exe   ", "")]
    [InlineData("", "")]
    [InlineData(@"`C:\No Ports\npt.exe`-d x", "-d x")]
    [InlineData(@"`C:\No Ports\npt.exe``  x`", "`  x`")]
    [InlineData(@"`C:\No Ports\npt.exe -d x", "")]
    [InlineData(@"C:\`Program Files`\npt.exe -d", @"Files`\npt.exe -d")]
    [InlineData(" npt.exe -d", "npt.exe -d")]
    [InlineData(@"npt.exe `C:\dir with space\\` C:\dir\ a\`b `c\`d` e\\\`f", @"`C:\dir with space\\` C:\dir\ a\`b `c\`d` e\\\`f")]
    [InlineData("npt.exe -d \u00e9t\u00e9 \u4e2d", "-d \u00e9t\u00e9 \u4e2d")]
    public void TheTailIsEverythingAfterTheProgramNameUnchanged(string commandLine, string tail)
    {
        Assert.Equal(Q(tail), Launch.ArgumentTail(Q(commandLine)));
    }

    [Fact]
    public void TheChildRunsAtscByItsQuotedPathWithTheCommandFirst()
    {
        Assert.Equal(Q($"`{AtscPath}` npt -d `my device`"), Launch.ChildCommandLine(AtscPath, "npt", Q("-d `my device`")));
        Assert.Equal(Q($"`{AtscPath}` npt"), Launch.ChildCommandLine(AtscPath, "npt", ""));
    }

    [Fact]
    public void TheFiveArgumentScenarioReachesAtscNptExactly()
    {
        string typed = Q($"`{NptPath}` -d `my device` `` --key=`a b` -");
        string[] five = { "-d", "my device", "", "--key=a b", "-" };
        Assert.Equal(new[] { NptPath }.Concat(five), WindowsArgv.Split(typed));

        string? error = Launch.TryPlan(@"C:\Program Files\NoPorts\NPT.exe", @"C:\Program Files\NoPorts\NPT.exe", typed, out string command, out string atscPath, out string child);

        Assert.Null(error);
        Assert.Equal("npt", command);
        Assert.Equal(AtscPath, atscPath);
        Assert.Equal(Q($"`{AtscPath}` npt -d `my device` `` --key=`a b` -"), child);
        Assert.Equal(new[] { AtscPath, "npt" }.Concat(five), WindowsArgv.Split(child));
    }

    [Theory]
    [MemberData(nameof(CommandLines))]
    public void AtscSeesTheSameArgumentsTheLauncherWasGiven(string commandLine)
    {
        string line = Q(commandLine);
        Assert.Null(Launch.TryPlan(NptPath, NptPath, line, out _, out _, out string child));

        List<string> given = WindowsArgv.Split(line);
        List<string> seen = WindowsArgv.Split(child);

        Assert.Equal(new[] { AtscPath, "npt" }.Concat(given.Skip(1)), seen);
    }

    public static IEnumerable<object[]> CommandLines() => new[]
    {
        @"`C:\Program Files\NoPorts\npt.exe` -d `my device` `` --key=`a b` -",
        @"C:\NoPorts\npt.exe -d `my device` `` --key=`a b` -",
        "npt.exe\t-d\tx  ",
        @"`C:\No Ports\npt.exe`-d x",
        @"`C:\No Ports\npt.exe``  x`",
        @"`C:\No Ports\npt.exe -d x",
        @"C:\`Program Files`\npt.exe -d",
        " npt.exe -d",
        @"npt.exe `C:\dir with space\\` C:\dir\ a\`b `c\`d` e\\\`f",
        @"npt.exe `two``quotes next three```quotes `three``` quotes` next",
        @"npt.exe arg1 `",
        @"npt.exe -d `a b  ",
        @"npt.exe ``",
        "npt.exe",
        "",
    }.Select(l => new object[] { l });

    [Theory]
    [InlineData(@"exe arg1 arg2 `arg three`", new[] { "exe", "arg1", "arg2", "arg three" })]
    [InlineData(@"exe `one\` still` `two\\` end", new[] { "exe", "one` still", @"two\", "end" })]
    [InlineData(@"exe o\ne t\\wo", new[] { "exe", @"o\ne", @"t\\wo" })]
    [InlineData(@"exe \`one \\`two` \\\`three", new[] { "exe", "`one", @"\two", @"\`three" })]
    [InlineData(@"exe `two``quotes next", new[] { "exe", "two`quotes", "next" })]
    [InlineData(@"exe three```quotes next", new[] { "exe", "three`quotes", "next" })]
    [InlineData(@"`exe`arg` one` argtwo", new[] { "exe", "arg one", "argtwo" })]
    [InlineData(@" `arg`one argtwo", new[] { "", "argone", "argtwo" })]
    [InlineData(@"exe`file`path arg1", new[] { "exe`file`path", "arg1" })]
    [InlineData(@"`two`` arg1 ", new[] { "two", " arg1 " })]
    [InlineData(@"exe arg1 `", new[] { "exe", "arg1", "" })]
    [InlineData(@"exe ``", new[] { "exe", "" })]
    public void TheReferenceSplitterFollowsCommandLineToArgvW(string commandLine, string[] args)
    {
        Assert.Equal(args.Select(Q), WindowsArgv.Split(Q(commandLine)));
    }

    [Fact]
    public void AtscJoinsTheJobBeforeItRuns()
    {
        var child = new FakeSuspendedChild();

        Assert.Null(Launch.Release(child, "npt", AtscPath));
        Assert.Equal(new[] { "join", "resume" }, child.Steps);
    }

    [Fact]
    public void AnAtscThatCannotJoinTheJobIsEndedBeforeItRuns()
    {
        var child = new FakeSuspendedChild(joinError: 5);

        Assert.Equal(
            $"npt: cannot run {AtscPath} in a job that ends it with this launcher (Windows error 5)",
            Launch.Release(child, "npt", AtscPath));
        Assert.Equal(new[] { "join", "terminate 127" }, child.Steps);
    }

    [Fact]
    public void AnAtscThatCannotResumeIsEnded()
    {
        var child = new FakeSuspendedChild(resumeError: 6);

        Assert.Equal($"npt: cannot resume {AtscPath} (Windows error 6)", Launch.Release(child, "npt", AtscPath));
        Assert.Equal(new[] { "join", "resume", "terminate 127" }, child.Steps);
    }

    [Fact]
    public void TheWin32ConstantsHaveTheirDocumentedValues()
    {
        Assert.Equal(0x4u, Native.CreateSuspended);
        Assert.Equal(0x8u, Native.DetachedProcess);
        Assert.Equal(0x100u, Native.StartfUseStdHandles);
        Assert.Equal(0x2000u, Native.JobObjectLimitKillOnJobClose);
        Assert.Equal(0x1000u, Native.JobObjectLimitSilentBreakawayOk);
        Assert.Equal(9, Native.JobObjectExtendedLimitInformationClass);
        Assert.Equal(0x1u, Native.FileShareRead);
        Assert.Equal(0x2u, Native.FileShareWrite);
        Assert.Equal(2u, Native.CtrlCloseEvent);
    }

    [Fact]
    public void TheLaunchersOwnFailuresExitWith127AsTheUnixLaunchersDo()
    {
        Assert.Equal(127, Launch.FailureExitCode);
    }

    [Theory]
    [InlineData(2)]
    [InlineData(3)]
    public void AMissingAtscIsNamed(int error)
    {
        Assert.Equal(
            $@"npt: cannot find {AtscPath}; NoPorts needs atsc.exe beside npt.exe",
            Launch.StartFailure("npt", AtscPath, error));
    }

    [Fact]
    public void AnotherStartFailureGivesTheWindowsError()
    {
        Assert.Equal($"npt: cannot start {AtscPath} (Windows error 5)", Launch.StartFailure("npt", AtscPath, 5));
    }

    [Fact]
    public unsafe void TheNativeStructuresHaveTheirWin64Layout()
    {
        Assert.Equal(8, sizeof(nint));
        Assert.Equal(104, sizeof(StartupInfo));
        Assert.Equal(60, (int)Marshal.OffsetOf<StartupInfo>(nameof(StartupInfo.Flags)));
        Assert.Equal(80, (int)Marshal.OffsetOf<StartupInfo>(nameof(StartupInfo.StdInput)));
        Assert.Equal(96, (int)Marshal.OffsetOf<StartupInfo>(nameof(StartupInfo.StdError)));
        Assert.Equal(24, sizeof(ProcessInformation));
        Assert.Equal(144, sizeof(JobExtendedLimitInformation));
        Assert.Equal(16, (int)Marshal.OffsetOf<JobExtendedLimitInformation>(nameof(JobExtendedLimitInformation.LimitFlags)));
        Assert.Equal(64, (int)Marshal.OffsetOf<JobExtendedLimitInformation>(nameof(JobExtendedLimitInformation.ReadOperationCount)));
    }

    private sealed class FakeSuspendedChild : ISuspendedChild
    {
        private readonly int _joinError;
        private readonly int _resumeError;

        internal FakeSuspendedChild(int joinError = 0, int resumeError = 0)
        {
            _joinError = joinError;
            _resumeError = resumeError;
        }

        internal List<string> Steps { get; } = new();

        public bool TryJoinJob(out int error)
        {
            Steps.Add("join");
            error = _joinError;
            return error == 0;
        }

        public bool TryResume(out int error)
        {
            Steps.Add("resume");
            error = _resumeError;
            return error == 0;
        }

        public void Terminate(int exitCode)
        {
            Steps.Add($"terminate {exitCode}");
        }
    }
}
