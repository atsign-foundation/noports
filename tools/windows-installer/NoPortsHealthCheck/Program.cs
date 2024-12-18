using Microsoft.Win32;
using NoPortsInstaller;
using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Principal;
using System.Windows.Forms;

namespace NoPortsHealthCheck
{
    internal static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Form1());
        }


        private static readonly List<string> logs = new List<string>();


        public static bool CanWriteToDirectory(string path)
        {
            try
            {
                string testFilePath = Path.Combine(path, "test.txt");
                File.WriteAllText(testFilePath, "test");
                Log($"Wrote to directory: {path}");
                File.Delete(testFilePath);
                Log($"Deleted file: {testFilePath}");
                return true;
            }
            catch (Exception ex)
            {
                LogErr($"Failed {path}", ex);
                ShowErrorLogs();
                return false;
            }
        }

        public static bool IsUserAdmin()
        {
            using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
            {
                WindowsPrincipal principal = new WindowsPrincipal(identity);
                try
                {
                    Log($"Account: {principal.Identity}");
                    return principal.IsInRole(WindowsBuiltInRole.Administrator);
                }
                catch (Exception ex)
                {
                    LogErr("Failed to check if user is admin", ex);
                    ShowErrorLogs();
                    return false;
                }
            }
        }

        public static bool CanWriteToRegistry(RegistryKey baseKey, string subKey)
        {
            try
            {
                Log("Creating registry key");
                baseKey.CreateSubKey(subKey);
            }
            catch (Exception ex)
            {
                LogErr($"Failed to create registry key {baseKey} {subKey}", ex);
                ShowErrorLogs();
                return false;
            }

            try
            {
                using (var key = baseKey.OpenSubKey(subKey, true))
                {
                    key.SetValue("test", "test");
                    Log("Wrote to registry key");
                    key.DeleteValue("test");
                    Log("Deleted registry key");
                    return true;
                }
            }
            catch (Exception ex)
            {
                LogErr($"Failed to write to registry {baseKey} {subKey}", ex);
                ShowErrorLogs();
                return false;
            }
        }

        public static bool CanModifyEnvironmentVariable()
        {
            try
            {
                Environment.SetEnvironmentVariable("TEST_ENV_VAR", "test_value", EnvironmentVariableTarget.User);
                Log("Modified environment variable");
                Environment.SetEnvironmentVariable("TEST_ENV_VAR", null, EnvironmentVariableTarget.User); // Clean up
                Log("Deleted environment variable");
                return true;
            }
            catch (Exception ex)
            {
                LogErr("Failed to modify environment variable", ex);
                ShowErrorLogs();
                return false;
            }
        }

        public static bool CanCreateServices()
        {
            try
            {
                ServiceController.Install("TestService", "Test Service", "C:\\Windows\\System32\\svchost.exe");
                ServiceController.TryUninstall("TestService");
                return true;
            }
            catch (Exception ex)
            {
                LogErr("Failed to create service", ex);
                ShowErrorLogs();
                return false;
            }
        }

        public static void Log(string what)
        {
            logs.Add(what);
        }

        public static void LogErr(string what, Exception ex)
        {
            logs.Add($"{what} - {ex.Message}  Stack Trace {ex.StackTrace}");
        }

        public static void ShowSuccessLogs()
        {
            MessageBox.Show($"All checks passed \n \n {string.Join(Environment.NewLine, logs)}", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        public static void ShowErrorLogs()
        {
            MessageBox.Show(string.Join(Environment.NewLine, logs), "Health Check Failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
