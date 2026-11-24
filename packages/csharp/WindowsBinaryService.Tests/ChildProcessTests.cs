using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Xunit;

namespace WindowsBinaryService.Tests;

/// <summary>Tests for how the sshnpd service starts atsc.</summary>
public class ChildProcessTests
{
    private static readonly string Installation = Path.Join(Path.GetTempPath(), "NoPorts");

    [Fact]
    public void TheServiceRunsTheAtscInItsOwnDirectoryAsSshnpd()
    {
        ProcessStartInfo startInfo = ChildProcess.StartInfo(Installation, Array.Empty<string>());

        Assert.Equal(Path.Join(Installation, "atsc.exe"), startInfo.FileName);
        Assert.True(Path.IsPathFullyQualified(startInfo.FileName), startInfo.FileName);
        Assert.Equal(new[] { "sshnpd" }, startInfo.ArgumentList);
        Assert.Equal("", startInfo.Arguments);
        Assert.False(startInfo.UseShellExecute);
    }

    [Fact]
    public void EachServiceArgumentReachesSshnpdUnchanged()
    {
        string[] arguments =
        {
            "-a", "@device", "-k", @"C:\Users\me\.atsign\keys\a b.atKeys", "", "say \"hi\"", @"C:\dir\", "-",
        };

        ProcessStartInfo startInfo = ChildProcess.StartInfo(Installation, arguments);

        Assert.Equal(new[] { "sshnpd" }.Concat(arguments), startInfo.ArgumentList);
        Assert.Equal("", startInfo.Arguments);
    }
}
