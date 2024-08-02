using Microsoft.Win32;
using System.Diagnostics;
using System.Text;

namespace SshnpdService
{
    public sealed class Sshnpd
    {
        private string GetArgs()
        {
            try
            {
                RegistryKey? registryKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\NoPorts");
                if (registryKey != null)
                {
                    object? deviceArgs = registryKey.GetValue("DeviceArgs");
                    if (deviceArgs != null)
                    {
                        return deviceArgs.ToString()!;
                    }
                }
            }
            catch
            {
                throw;
            }
            return string.Empty;
        }

        private string GetBinPath()
        {
            try
            {
                RegistryKey? registryKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\NoPorts");
                if (registryKey != null)
                {
                    object? binPath = registryKey.GetValue("BinPath");
                    if (binPath != null)
                    {
                        return binPath.ToString() + @"\sshnpd.exe";
                    }
                }
            }
            catch
            {
                throw;
            }
            return string.Empty;
        }

        public void Close()
        {
            try
            {
                Process[] processes = Process.GetProcessesByName("sshnpd");
                foreach (Process process in processes)
                {
                    try
                    {
                        // Attempt to close the process gracefully
                        process.CloseMainWindow();
                        process.WaitForExit(3000); // Wait for 3 seconds for the process to exit
                        if (!process.HasExited)
                        {
                            // Forcefully terminate the process if it does not close gracefully
                            process.Kill();
                        }
                        process.Dispose();
                    }
                    catch
                    {
                        throw;
                    }
                }
            }
            catch
            {
                // Log any exceptions that occur while retrieving the processes
                throw;
            }
        }

        public async Task Run(CancellationToken cancellationToken)
        {
            var args = GetArgs();
            // Use ProcessStartInfo class
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.CreateNoWindow = false;
            startInfo.UseShellExecute = false;
            startInfo.FileName = GetBinPath();
            startInfo.WindowStyle = ProcessWindowStyle.Hidden;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;

            startInfo.Arguments = GetArgs();

            StringBuilder stdout = new StringBuilder();
            StringBuilder stderr = new StringBuilder();

            try
            {
                using Process exeProcess = Process.Start(startInfo)!;
                //Event Log has a default limit of 32KB per entry
                int bufferLimit = 16384;
                int outLines = 0;
                int errLines = 0;
                exeProcess.OutputDataReceived += (sender, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        stdout.AppendLine(e.Data);
                        if (stdout.Length >= bufferLimit || outLines >= 5)
                        {
                            EventLog.WriteEntry("NoPorts", stdout.ToString(), EventLogEntryType.Information);
                            stdout.Clear();
                        }
                        outLines++;
                    }
                };
                exeProcess.ErrorDataReceived += (sender, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        stderr.AppendLine(e.Data);
                        if (stderr.Length >= bufferLimit || errLines >= 5)
                        {
                            EventLog.WriteEntry("NoPorts", stderr.ToString(), EventLogEntryType.Information);
                            stderr.Clear();
                        }
                        errLines++;
                    }
                };

                exeProcess.BeginOutputReadLine();
                exeProcess.BeginErrorReadLine();
                await exeProcess.WaitForExitAsync(cancellationToken);
                return;
            }
            catch
            {
                throw;
            }
        }
    }
}
