using Microsoft.Win32;
using NoPortsInstaller.Pages;
using System.Diagnostics;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Windows;
using System.Windows.Controls;
namespace NoPortsInstaller
{
    public class Controller : IController
    {
        public string InstallDirectory { get; set; }
        public InstallType InstallType { get; set; }
        public string ClientAtsign { get; set; }
        public string DeviceAtsign { get; set; }
        public string DeviceName { get; set; }
        public string RegionAtsign { get; set; }
        public string PermittedPorts { get; set; }
        public string MultipleDevices { get; set; }
        public string MultipleManagers { get; set; }
        public bool IsInstalled { get { return Directory.Exists(InstallDirectory); } set { } }
        public List<Page> Pages { get; set; }
        public string AtkeysPath { get; set; }
        private int index = 0;
        public Window? Window { get; set; }

        public Controller()
        {
            InstallDirectory = "C:\\Program Files\\NoPorts";
            InstallType = InstallType.None;
            ClientAtsign = "";
            DeviceAtsign = "";
            DeviceName = "";
            RegionAtsign = "";
            MultipleDevices = "";
            MultipleManagers = "";
            PermittedPorts = "localhost:22,localhost:3389";
            Pages = [];
            IsInstalled = false;
            AtkeysPath = "";
        }

        /// <summary>
        /// Installs NoPorts depending on the InstallType.
        /// </summary>
        /// <param name="progress"></param>
        /// <param name="status"></param>
        public async Task Install(ProgressBar progress, Label status)
        {
            try
            {
                status.Content = "Creating directories...";
                CreateDirectories(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile));
                await UpdateProgressBar(progress, 25);
                status.Content = "Installing NoPorts...";
                await MoveResources();
                VerifyInstall();
                status.Content = "Updating Trusted Certificates...";
                await UpdateProgressBar(progress, 50);
                UpdateTrustedCerts();
                await UpdateProgressBar(progress, 75);
                status.Content = "Creating Registries NoPorts...";
                CreateRegistryKeys();
                await UpdateProgressBar(progress, 90);
                if (InstallType.Equals(InstallType.Device) || InstallType.Equals(InstallType.Both))
                {
                    status.Content = "Setting up NoPorts Service...";
                    CopyIntoServiceAccount();
                    await SetupService(status);
                }
                await Task.Run(() => ServiceController.CreateUninstaller(Path.Combine(Path.GetDirectoryName(Environment.ProcessPath)!, "NoPortsInstaller.exe u")));
                await UpdateProgressBar(progress, 100);
                Pages.Add(new FinishInstall());
                NextPage();
            }
            catch (Exception ex)
            {
                await Cleanup();
                Pages.Add(new ServiceErrorPage(ex.Message));
                NextPage();
            }
        }

        /// <summary>
        /// Uninstalls NoPorts, including the service.
        /// </summary>
        /// <param name="progress"></param>
        public async Task Uninstall(ProgressBar progress)
        {
            try
            {
                RegistryKey? registryKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\NoPorts");
                object? binPath = null;
                if (registryKey != null)
                {
                    binPath = registryKey.GetValue("BinPath");
                    Registry.LocalMachine.DeleteSubKey(@"SOFTWARE\NoPorts");
                    Registry.LocalMachine.DeleteSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\NoPorts");
                }

                await ServiceController.TryUninstall("sshnpd");

                if (binPath != null)
                {
                    DirectoryInfo di = new(binPath.ToString()!);
                    foreach (FileInfo file in di.GetFiles())
                    {
                        file.Delete();
                    }
                    foreach (DirectoryInfo dir in di.GetDirectories())
                    {
                        dir.Delete(true);
                    }
                    di.Delete();
                }
                await UpdateProgressBar(progress, 100);
            }
            catch (Exception ex)
            {
                Pages.Add(new ServiceErrorPage(ex.Message));
                NextPage();
            }
        }

        public void UpdateConfigRegistry()
        {
            try
            {
                RegistryKey? registryKey = Registry.LocalMachine.OpenSubKey(@"Software\NoPorts");
                if (registryKey != null)
                {
                    registryKey.SetValue("DeviceArgs", $"-a {DeviceAtsign} -m {ClientAtsign} -d {DeviceName} -sv");
                    registryKey.Close();
                }
            }
            catch (Exception ex)
            {
                Pages.Add(new ServiceErrorPage(ex.Message));
                NextPage();
            }
        }

        private void CreateDirectories(string userHome)
        {
            DirectorySecurity securityRules = new();
            DirectoryInfo di;
            securityRules.AddAccessRule(new FileSystemAccessRule("Users", FileSystemRights.Modify, AccessControlType.Allow));
            string[] directories =
            [
                Path.Combine(userHome, ".ssh"),
                Path.Combine(userHome, ".sshnp"),
                Path.Combine(userHome, ".atsign"),
                Path.Combine(userHome, ".atsign", "keys"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Temp\NoPorts"),
                InstallDirectory
            ];

            foreach (string dir in directories)
            {
                try
                {
                    if (!Directory.Exists(dir))
                    {
                        Directory.CreateDirectory(dir);
                        di = new DirectoryInfo(dir);
                        di.SetAccessControl(securityRules);
                        Console.WriteLine($"Directory created: {dir}");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"An error occurred while creating {dir}: {ex.Message}");
                }
            }
            if (InstallType.Equals(InstallType.Client))
            {
                MoveUploadedAtkeys();
            }

            SecurityIdentifier everyone = new(WellKnownSidType.WorldSid, null);
            securityRules = new();
            securityRules.AddAccessRule(new FileSystemAccessRule(everyone, FileSystemRights.Modify | FileSystemRights.Synchronize, InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Allow));
            di = new DirectoryInfo(directories.Last());
            di.SetAccessControl(securityRules);
            var authkeys = Path.Combine(userHome, ".ssh", "authorized_keys");
            if (!System.IO.File.Exists(authkeys))
            {
                FileInfo fi = new(authkeys);
                fi.Create().Close();
            }

        }

        private void CopyIntoServiceAccount()
        {
            string sourceFile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string destinationFile = Environment.ExpandEnvironmentVariables("%systemroot%") + @"\ServiceProfiles\NetworkService\";
            string[] sources =
            [
                Path.Combine(sourceFile, ".ssh", "authorized_keys"),
                AtkeysPath
            ];
            CreateDirectories(destinationFile);
            string[] destinations =
            [
                Path.Combine(destinationFile, ".ssh", "authorized_keys"),
                Path.Combine(destinationFile, ".atsign", "keys", DeviceAtsign + "_key.atKeys")
            ];
            for (int i = 0; i < sources.Length; i++)
            {
                try
                {
                    if (System.IO.File.Exists(sources[i]))
                    {
                        System.IO.File.Copy(sources[i], destinations[i], true);
                    }
                }
                catch
                {
                    throw new FileNotFoundException("No keys found. Use at_activate to onboard keys or enroll/approve this device.");
                }
            }
        }

        private async Task MoveResources()
        {
            Dictionary<byte[], string> resources = new()
            {
                { Properties.Resources.at_activate, "at_activate.exe" },
                { Properties.Resources.srv, "srv.exe" }
            };

            if (InstallType.Equals(InstallType.Device))
            {
                await ServiceController.TryUninstall("sshnpd");
                resources.Add(Properties.Resources.sshnpd, "sshnpd.exe");
                resources.Add(Properties.Resources.SshnpdService, "SshnpdService.exe");
            }
            else if (InstallType.Equals(InstallType.Client))
            {
                resources.Add(Properties.Resources.sshnp, "sshnp.exe");
                resources.Add(Properties.Resources.npt, "npt.exe");
            }
            else if (InstallType.Equals(InstallType.Both))
            {
                await ServiceController.TryUninstall("sshnpd");
                resources.Add(Properties.Resources.sshnpd, "sshnpd.exe");
                resources.Add(Properties.Resources.SshnpdService, "SshnpdService.exe");
                resources.Add(Properties.Resources.sshnp, "sshnp.exe");
                resources.Add(Properties.Resources.npt, "npt.exe");
            }

            foreach (var resource in resources)
            {
                string path = Path.Combine(InstallDirectory, resource.Value);
                await Task.Run(() => System.IO.File.WriteAllBytes(path, resource.Key));
            }
        }

        private async Task SetupService(Label status)
        {
            if (!EventLog.SourceExists("NoPorts"))
            {
                EventLog.CreateEventSource("NoPorts", "NoPorts");
            }

            try
            {
                status.Content = "Installing sshnpd service...";
                await Task.Run(() =>
                    ServiceController.InstallAndStart("sshnpd", "sshnpd", InstallDirectory + @"\SshnpdService.exe")
                );
                status.Content = "Configuring the Windows Service...";
                await Task.Run(() => ServiceController.SetRecoveryOptions("sshnpd"));
            }
            catch
            {
                throw;
            }
            Process.Start("sc", "description sshnpd NoPorts-SSH-Daemon");
            return;
        }

        private static void UpdateTrustedCerts()
        {
            var tempPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Temp\trusted-certs");
            if (!Directory.Exists(tempPath))
            {
                Directory.CreateDirectory(tempPath);
            }
            tempPath += @"\roots.sst";
            ProcessStartInfo startInfo = new()
            {
                FileName = "Certutil.exe",
                Arguments = $"-generateSSTFromWU {tempPath}",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (Process? process = Process.Start(startInfo))
            {
                if (process != null)
                {
                    process.WaitForExit();
                }
            }

            startInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Verb = "runas",
                Arguments = $"-WindowStyle Hidden -Command \"(Get-ChildItem '{tempPath}') | Import-Certificate -CertStoreLocation Cert:\\LocalMachine\\Root\"",
                UseShellExecute = true,
                CreateNoWindow = true
            };

            using (Process? process = Process.Start(startInfo))
            {
                if (process != null)
                {
                    process.WaitForExit();
                }
            }
        }

        private void CreateRegistryKeys()
        {
            RegistryKey registryKey = Registry.LocalMachine.CreateSubKey(@"Software\NoPorts");
            registryKey.SetValue("BinPath", InstallDirectory);
            var args = $"-a {DeviceAtsign} -m {ClientAtsign} -d {DeviceName}";
            if (MultipleManagers != "")
            {
                args += $" --managers {MultipleManagers}";
            }
            args += " -sv";
            if (InstallType.Equals(InstallType.Device) || InstallType.Equals(InstallType.Both))
            {
                registryKey.SetValue("DeviceArgs", args);
            }
            registryKey.Close();
        }

        private static Task Cleanup()
        {
            return Task.Run(() =>
            {
                try
                {
                    Directory.Delete(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Temp\NoPorts"), true);
                    RegistryKey? registryKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\NoPorts");
                    if (registryKey != null)
                    {
                        registryKey.DeleteValue("BinPath");
                        registryKey.DeleteValue("DeviceArgs");
                        registryKey.Close();
                    }
                }
                catch
                {
                }
            });
        }



        /// <summary>
        /// Loads the appropriate pages based on the InstallType.
        /// </summary>
        public void LoadPages()
        {
            switch (InstallType)
            {
                case InstallType.None:
                    Pages.Add(new Setup());
                    break;
                case InstallType.Update:
                    Pages.Clear();
                    Pages.Add(new Setup());
                    Pages.Add(new ConfigureInstall());
                    Pages.Add(new UpdateDevice());
                    break;
                case InstallType.Uninstall:
                    Pages.Clear();
                    Pages.Add(new UninstallPage());
                    break;
                case InstallType.Client:
                    Pages.Add(new ClientConfig());
                    break;
                default:
                    Pages.Add(new ConfigureInstall());
                    Pages.Add(new DeviceConfig());
                    break;
            }
            if (Window != null)
            {
                Window.Content = Pages[index];
            }
            else
            {
                Pages.Add(new ServiceErrorPage("Window is null"));
            }
        }

        /// <summary>
        /// Moves to the next page in the Pages list.
        /// </summary>
        public void NextPage()
        {
            if (index < Pages.Count - 1)
            {
                index++;
            }
            Window!.Content = Pages[index];
        }

        /// <summary>
        /// Moves to the previous page in the Pages list.
        /// </summary>
        public void PreviousPage()
        {
            if (index > 0)
            {
                index--;
            }
            Window!.Content = Pages[index];
        }

        /// <summary>
        /// Updates the progress bar value asynchronously.
        /// </summary>
        /// <param name="pb">The progress bar control.</param>
        /// <param name="value">The target value for the progress bar.</param>
        /// <returns>A task representing the asynchronous operation.</returns>
        private async static Task UpdateProgressBar(ProgressBar pb, int value)
        {
            double start = pb.Value;
            await Task.Run(() =>
            {
                for (double i = start; i <= value; i++)
                {
                    pb.Dispatcher.Invoke(() => pb.Value = i);
                    Thread.Sleep(20);
                }
            });
        }


        /// <summary>
        /// Populates the given ComboBox with available Atsigns.
        /// </summary>
        /// <param name="box">The ComboBox control to populate.</param>
        public void PopulateAtsigns(ComboBox box)
        {
            List<string> files = [];
            if (Directory.Exists(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys")))
            {
                files = Directory.GetFiles(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys"), "*.atKeys", SearchOption.AllDirectories).ToList();
            }
            foreach (var key in files)
            {
                ComboBoxItem item = new();
                item.Content = Path.GetFileNameWithoutExtension(key).Replace("_key", "");
                box.Items.Add(item);
            }
        }

        /// <summary>
        /// Normalizes the given Atsign by adding the '@' symbol if it is missing.
        /// </summary>
        /// <param name="atsign">The Atsign to normalize.</param>
        /// <returns>The normalized Atsign.</returns>
        public string NormalizeAtsign(string atsign)
        {
            if (atsign.StartsWith('@'))
            {
                return atsign;
            }
            else
            {
                return "@" + atsign;
            }
        }

        public string NormalizeMultipleManagers(string atsigns)
        {
            string[] atsignArray = atsigns.Split(',');
            for (int i = 0; i < atsignArray.Length; i++)
            {
                atsignArray[i] = NormalizeAtsign(atsignArray[i]);
            }
            return string.Join(',', atsignArray);
        }

        public string NormalizePermittedPorts(string ports)
        {
            string[] portArray = ports.Split(',');
            for (int i = 0; i < portArray.Length; i++)
            {
                if (!portArray[i].Contains(':'))
                {
                    portArray[i] = "localhost:" + portArray[i];
                }
            }
            return string.Join(',', portArray);
        }

        public void VerifyInstall()
        {
            string[] dirs = { "at_activate.exe", "srv.exe" };
            foreach (var dir in dirs)
            {
                string sourceFilePath = Path.Combine(InstallDirectory, dir);
                if (!File.Exists(sourceFilePath))
                {
                    throw new Exception("File not found: " + sourceFilePath);
                }
            }
        }

        public void MoveUploadedAtkeys()
        {
            if (AtkeysPath != "")
            {
                string destination = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".atsign", "keys");
                if (Directory.Exists(destination))
                {
                    File.Move(AtkeysPath, Path.Combine(destination, Path.GetFileName(AtkeysPath)));
                    AtkeysPath = Path.Combine(destination, Path.GetFileName(AtkeysPath));
                }
            }
        }
    }
}

public enum InstallType
{
    None,
    Device,
    Client,
    Both,
    Update,
    Uninstall
}

