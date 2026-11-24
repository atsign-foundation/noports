using System.Collections.Generic;
using System.Text;

namespace AtscLauncher.Tests;

/// <summary>Splits a Windows command line into arguments the way CommandLineToArgvW does.</summary>
internal static class WindowsArgv
{
    /// <summary>Returns the program name followed by each argument of <paramref name="line"/>.</summary>
    internal static List<string> Split(string line)
    {
        var args = new List<string>();
        var arg = new StringBuilder();
        int i = 0;
        if (line.Length > 0 && line[0] == '"')
        {
            int close = line.IndexOf('"', 1);
            arg.Append(close < 0 ? line.Substring(1) : line.Substring(1, close - 1));
            i = close < 0 ? line.Length : close + 1;
        }
        else
        {
            while (i < line.Length && line[i] != ' ' && line[i] != '\t')
            {
                arg.Append(line[i++]);
            }
        }

        args.Add(arg.ToString());
        while (true)
        {
            while (i < line.Length && (line[i] == ' ' || line[i] == '\t'))
            {
                i++;
            }

            if (i >= line.Length)
            {
                return args;
            }

            arg.Clear();
            int quotes = 0;
            while (i < line.Length)
            {
                char c = line[i];
                if ((c == ' ' || c == '\t') && quotes == 0)
                {
                    break;
                }

                if (c == '\\')
                {
                    int backslashes = 0;
                    while (i < line.Length && line[i] == '\\')
                    {
                        backslashes++;
                        i++;
                    }

                    if (i < line.Length && line[i] == '"')
                    {
                        arg.Append('\\', backslashes / 2);
                        if (backslashes % 2 == 1)
                        {
                            arg.Append('"');
                            i++;
                        }
                    }
                    else
                    {
                        arg.Append('\\', backslashes);
                    }

                    continue;
                }

                if (c == '"')
                {
                    quotes++;
                    i++;
                    while (i < line.Length && line[i] == '"')
                    {
                        if (++quotes == 3)
                        {
                            arg.Append('"');
                            quotes = 0;
                        }

                        i++;
                    }

                    if (quotes == 2)
                    {
                        quotes = 0;
                    }

                    continue;
                }

                arg.Append(c);
                i++;
            }

            args.Add(arg.ToString());
        }
    }
}
