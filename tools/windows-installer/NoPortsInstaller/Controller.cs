using Microsoft.Win32;
using NoPortsInstaller.Pages;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Security.AccessControl;
using System.Text.Json;
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
        private string PermittedPorts { get; set; }
        public string MultipleDevices { get; set; }
        public bool IsInstalled { get { return Directory.Exists(InstallDirectory); } set { } }
        public List<Page> Pages { get; set; }
        private int index = 0;
        public Window? Window { get; set; }
        private string archiveDirectory;

        public Controller()
        {
            InstallDirectory = "C:\\Program Files\\NoPorts";
            InstallType = InstallType.None;
            ClientAtsign = "";
            DeviceAtsign = "";
            DeviceName = "";
            RegionAtsign = "";
            MultipleDevices = "";
            PermittedPorts = "localhost:22,localhost:3389";
            Pages = [];
            IsInstalled = false;
            archiveDirectory = Path.GetFullPath(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Temp\NoPorts\"));
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
                status.Content = "Downloading NoPorts...";
                await DownloadArchive();
                await UpdateProgressBar(progress, 50);
                ExtractArchive();
                status.Content = "Updating Trusted Certificates...";
                UpdateTrustedCerts();
                await UpdateProgressBar(progress, 75);
                status.Content = "Creating Registries NoPorts...";
                CreateRegistryKeys();
                await UpdateProgressBar(progress, 90);
                status.Content = "Setting up NoPorts Service...";
                if (InstallType.Equals(InstallType.Device))
                {
                    CopyIntoServiceAccount();
                    await SetupService(status);
                }
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
                    registryKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\");
                    registryKey!.DeleteSubKeyTree("NoPorts");
                    registryKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall");
                    registryKey!.DeleteSubKeyTree("NoPorts");
                }


                if (ServiceController.ServiceIsInstalled("sshnpd"))
                {
                    try
                    {
                        ServiceController.StopService("sshnpd");
                    }
                    catch
                    {
                        throw;
                    }
                    await Task.Run(() => ServiceController.Uninstall("sshnpd"));
                }
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
                    di.Parent!.Delete();
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
            securityRules.AddAccessRule(new FileSystemAccessRule("Users", FileSystemRights.Modify, AccessControlType.Allow));
            string[] directories =
            [
                Path.Combine(userHome, ".ssh"),
                Path.Combine(userHome, ".sshnp"),
                Path.Combine(userHome, ".atsign"),
                Path.Combine(userHome, ".atsign", "keys"),
                InstallDirectory,
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Temp\NoPorts")
            ];

            foreach (string dir in directories)
            {
                try
                {
                    if (!Directory.Exists(dir))
                    {
                        Directory.CreateDirectory(dir);
                        var di = new DirectoryInfo(dir);
                        di.SetAccessControl(securityRules);
                        Console.WriteLine($"Directory created: {dir}");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"An error occurred while creating {dir}: {ex.Message}");
                }
            }
            var authkeys = Path.Combine(userHome, ".ssh", "authorized_keys");
            if (!File.Exists(authkeys))
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
                Path.Combine(sourceFile, ".atsign", "keys", DeviceAtsign + "_key.atKeys")
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
                    if (File.Exists(sources[i]))
                    {
                        File.Copy(sources[i], destinations[i], true);
                    }
                }
                catch
                {
                    throw new FileNotFoundException("No keys found. Use at_activate to onboard keys or enroll/approve this device.");
                }
            }
        }

        private async Task DownloadArchive()
        {
            HttpClient client = new();
            client.DefaultRequestHeaders.Add("User-Agent", "product/1");
            string content;
            var downloadUrl = "";
            JsonDocument jsonDocument;

            if (!Directory.Exists(archiveDirectory))
            {
                Directory.CreateDirectory(archiveDirectory);
            }
            HttpResponseMessage response = client.GetAsync("https://api.github.com/repos/atsign-foundation/noports/releases/latest").Result;
            if (!response.IsSuccessStatusCode)
            {
                throw new Exception("Failed to find latest release");
            }
            try
            {
                content = response.Content.ReadAsStringAsync().Result;
                jsonDocument = JsonDocument.Parse(content);
            }
            catch
            {
                throw new Exception("Failed to parse response");
            }

            foreach (var asset in jsonDocument.RootElement.GetProperty("assets").EnumerateArray())
            {
                if (asset.GetProperty("name").GetString() == "sshnp-windows-x64.zip")
                {
                    downloadUrl = asset.GetProperty("browser_download_url").GetString();
                    break;
                }
            }

            try
            {
                response = await client.GetAsync(downloadUrl);
                response.EnsureSuccessStatusCode();

                var fileInfo = new FileInfo(archiveDirectory);
                if (fileInfo.Directory != null && !fileInfo.Directory.Exists)
                {
                    fileInfo.Directory.Create();
                }

                byte[] fileBytes = response.Content.ReadAsByteArrayAsync().Result;
                archiveDirectory = Path.Combine(archiveDirectory, "sshnp-windows-x64.zip");
                await File.WriteAllBytesAsync(archiveDirectory, fileBytes);
            }
            catch
            {
                throw;
            }

            return;
        }

        private void ExtractArchive()
        {
            if (InstallType.Equals(InstallType.Device))
            {
                try
                {
                    if (ServiceController.ServiceIsInstalled("sshnpd"))
                    {
                        ServiceController.Uninstall("sshnpd");
                    }
                }
                catch
                {
                    throw;
                }
            }
            ZipFile.ExtractToDirectory(archiveDirectory!, InstallDirectory, overwriteFiles: true);
            InstallDirectory = Path.Combine(InstallDirectory, "sshnp");
            File.Delete(archiveDirectory!);
            if (InstallType.Equals(InstallType.Both)) { }
            else if (InstallType.Equals(InstallType.Device))
            {
                File.Delete(Path.Combine(InstallDirectory, "sshnp.exe"));
                File.Delete(Path.Combine(InstallDirectory, "npt.exe"));
                Directory.Delete(Path.Combine(InstallDirectory, "docker"), true);
            }
            else if (InstallType.Equals(InstallType.Client))
            {
                File.Delete(Path.Combine(InstallDirectory, "sshnpd.exe"));
                File.Delete(Path.Combine(InstallDirectory, "sshnpd_service.xml"));
                //File.Delete(Path.Combine(InstallDirectory, "SshnpdService.exe"));
            }
            var newValue = Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.Machine) + ";" + InstallDirectory;
            Environment.SetEnvironmentVariable("PATH", newValue, EnvironmentVariableTarget.Machine);
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
                {
                    try
                    {
                        ServiceController.InstallAndStart("sshnpd", "sshnpd", InstallDirectory + @"\SshnpdService.exe");
                    }
                    catch
                    {
                        throw;
                    }
                });
                status.Content = "Configuring the Windows Service...";
                await Task.Run(() => ServiceController.CreateUninstaller(System.AppDomain.CurrentDomain.BaseDirectory + @"NoPortsInstaller.exe u"));
                await Task.Run(() => ServiceController.SetRecoveryOptions("sshnpd"));
            }
            catch
            {
                status.Content = "Error setting up the service.";
            }
            Process.Start("sc", "description sshnpd NoPorts-SSH-Daemon");
            return;
        }

        private void UpdateTrustedCerts()
        {
            ProcessStartInfo startInfo = new()
            {
                FileName = "Certutil.exe",
                Arguments = "-generateSSTFromWU roots.sst",
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
                Arguments = "-Command \"$sstStore = Get-ChildItem -Path c:\\trusted-root-certs\\roots.sst; $sstStore | Import-Certificate -CertStoreLocation Cert:\\LocalMachine\\Root\"",
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

        }

        private void CreateRegistryKeys()
        {
            RegistryKey registryKey = Registry.LocalMachine.CreateSubKey(@"Software\NoPorts");
            registryKey.SetValue("BinPath", InstallDirectory);
            if (InstallType.Equals(InstallType.Device))
            {
                registryKey.SetValue("DeviceArgs", $"-a {DeviceAtsign} -m {ClientAtsign} -d {DeviceName} -sv");
            }
            registryKey.Close();
        }

        private Task Cleanup()
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
                case InstallType.Update:
                    Pages.Add(new UpdateConfigs());
                    break;
                case InstallType.Uninstall:
                    Pages.Add(new UninstallPage());
                    break;
                default:
                    Pages.Add(new Setup());
                    Pages.Add(new ConfigureInstall());
                    Pages.Add(new AdditionalConfiguration());
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
        private async Task UpdateProgressBar(ProgressBar pb, int value)
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
            string[] files = [];
            if (Directory.Exists(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys")))
            {
                files = Directory.GetFiles(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys"), "*.atKeys", SearchOption.AllDirectories);
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
}
