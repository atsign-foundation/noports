using Microsoft.Win32;
using NoPortsInstaller.Pages;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Security.AccessControl;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
namespace NoPortsInstaller
{
    public class Installer
    {
        public string InstallDirectory { get; set; }
        public bool DeviceInstall { get; set; }
        public bool ClientInstall { get; set; }
        public string ClientAtsign { get; set; }
        public string DeviceAtsign { get; set; }
        public string DeviceName { get; set; }
        public string RegionAtsign { get; set; }
        public string PermittedPorts { get; set; }
        public string MultipleDevices { get; set; }
        public bool IsInstalled { get { return Directory.Exists(InstallDirectory); } set { } }
        public List<Page> Pages { get; set; }
        private int index = 0;
        private MainWindow? window;
        private string? archiveDirectory;
        private string? serviceAccount = "NetworkService";

        public Installer()
        {
            InstallDirectory = "C:\\Program Files\\NoPorts";
            ClientInstall = false;
            DeviceInstall = false;
            ClientAtsign = "";
            DeviceAtsign = "";
            DeviceName = "";
            RegionAtsign = "";
            MultipleDevices = "";
            PermittedPorts = "localhost:22,localhost:3389";
            Pages = new List<Page> { new Setup(this), new ConfigureInstall(this) };
            IsInstalled = false;
        }

        public async void Install(ProgressBar progress)
        {
            try
            {
                CreateDirectories(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile));
                await UpdateProgress(progress, 25);
                await DownloadArchive();
                await UpdateProgress(progress, 50);
                ExtractArchive();
                await UpdateProgress(progress, 90);
                CreateRegistryKeys();
                if (DeviceInstall)
                {
                    CopyIntoServiceAccount();
                    await SetupService();
                }
                await UpdateProgress(progress, 100);
                NextPage();
            }
            catch
            {
                Pages.Add(new ServiceErrorPage());
            }
        }

        public async void Uninstall(ProgressBar progress)
        {
            try
            {
                RegistryKey? registryKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\NoPorts");
                object? binPath = null;
                if (registryKey != null)
                {
                    binPath = registryKey.GetValue("BinPath");
                }

                if (ServiceInstaller.ServiceIsInstalled("sshnpd"))
                {
                    try
                    {
                        ServiceInstaller.StopService("sshnpd");
                    }
                    catch
                    {
                        throw;
                    }
                    await Task.Run(() => ServiceInstaller.Uninstall("sshnpd"));
                }
                if (binPath != null)
                {
                    DirectoryInfo di = new DirectoryInfo(binPath.ToString()!);
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
                await UpdateProgress(progress, 100);

            }
            catch
            {
                throw;
            }
        }

        private void CreateDirectories(string userHome)
        {
            DirectorySecurity securityRules = new DirectorySecurity();
            securityRules.AddAccessRule(new FileSystemAccessRule("Users", FileSystemRights.Modify, AccessControlType.Allow));
            string[] directories = new string[]
            {
            Path.Combine(userHome, ".ssh"),
            Path.Combine(userHome, ".sshnp"),
            Path.Combine(userHome, ".atsign"),
            Path.Combine(userHome, ".atsign", "keys"),
            InstallDirectory,
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Temp\NoPorts")
            };

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
        }

        private void CopyIntoServiceAccount()
        {
            string sourceFile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string destinationFile = Environment.ExpandEnvironmentVariables("%systemroot%") + @"\ServiceProfiles\NetworkService\";
            string[] sources = new string[]
            {
                Path.Combine(sourceFile, ".ssh", "authorized_keys"),
                Path.Combine(sourceFile, ".atsign", "keys", DeviceAtsign + "_key.atKeys")
            };
            CreateDirectories(destinationFile);
            string[] destinations = new string[]
            {
                Path.Combine(destinationFile, ".ssh", "authorized_keys"),
                Path.Combine(destinationFile, ".atsign", "keys", DeviceAtsign + "_key.atKeys")
            };
            for (int i = 0; i < sources.Length; i++)
            {
                try
                {
                    File.Copy(sources[i], destinations[i], true);
                }
                catch
                {
                    throw;
                }
            }
        }

        private async Task DownloadArchive()
        {
            HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Add("User-Agent", "product/1");
            string content;
            var downloadUrl = "";
            JsonDocument jsonDocument;

            archiveDirectory = Path.GetFullPath(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Temp\NoPorts\"));
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
            catch (Exception ex)
            {
                throw;
            }

            return;
        }

        private void ExtractArchive()
        {
            if (DeviceInstall)
            {
                try
                {
                    if (ServiceInstaller.ServiceIsInstalled("sshnpd"))
                    {
                        ServiceInstaller.Uninstall("sshnpd");
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
            if (DeviceInstall && ClientInstall) { }
            else if (DeviceInstall)
            {
                File.Delete(Path.Combine(InstallDirectory, "sshnp.exe"));
                File.Delete(Path.Combine(InstallDirectory, "npt.exe"));
                Directory.Delete(Path.Combine(InstallDirectory, "docker"), true);
            }
            else if (ClientInstall)
            {
                File.Delete(Path.Combine(InstallDirectory, "sshnpd.exe"));
                File.Delete(Path.Combine(InstallDirectory, "sshnpd_service.xml"));
                //File.Delete(Path.Combine(InstallDirectory, "SshnpdService.exe"));
            }
            var newValue = Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.Machine) + ";" + InstallDirectory;
            Environment.SetEnvironmentVariable("PATH", newValue, EnvironmentVariableTarget.Machine);
        }

        private async Task SetupService()
        {
            if (!EventLog.SourceExists("NoPorts"))
            {
                EventLog.CreateEventSource("NoPorts", "NoPorts");
            }

            try
            {
                await Task.Run(() =>
                {
                    try
                    {
                        ServiceInstaller.InstallAndStart("sshnpd", "sshnpd", InstallDirectory + @"\SshnpdService.exe");
                    }
                    catch
                    {
                        throw;
                    }
                });
                await Task.Run(() => ServiceInstaller.CreateUninstaller(System.AppDomain.CurrentDomain.BaseDirectory + @"NoPortsInstaller.exe u"));
                await Task.Run(() => ServiceInstaller.SetRecoveryOptions("sshnpd"));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"An error occurred while setting up the service: {ex.Message}");
            }
            Process.Start("sc", "description sshnpd NoPorts SSH Daemon");
            return;
        }

        private void CreateRegistryKeys()
        {
            RegistryKey registryKey = Registry.LocalMachine.CreateSubKey(@"Software\NoPorts");
            registryKey.SetValue("BinPath", InstallDirectory);
            string KeyPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys", DeviceAtsign + "_key.atKeys");
            if (DeviceInstall)
            {
                registryKey.SetValue("DeviceArgs", $"-a {DeviceAtsign} -m {ClientAtsign} -d {DeviceName} -sv");
            }
        }

        private void UpdateConfigRegistry()
        {

        }

        public void NextPage()
        {
            if (index < Pages.Count - 1)
            {
                index++;
            }
            window!.Content = Pages[index];
        }

        public void PreviousPage()
        {
            if (index > 0)
            {
                index--;
            }
            window!.Content = Pages[index];
        }

        public void Setup(Window window)
        {
            this.window = (MainWindow)window;
            window.Content = Pages[0];
        }

        private async Task UpdateProgress(ProgressBar pb, int value)
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

        public bool VerifyAtsign()
        {
            if (ClientAtsign == "" || DeviceAtsign == "")
            {
                return false;
            }
            if (!Regex.IsMatch(ClientAtsign, @"^@?[a-zA-Z0-9]{1,20}$"))
            {
                ClientAtsign = "@" + ClientAtsign;
            }
            if (!Regex.IsMatch(DeviceAtsign, @"^@?[a-zA-Z0-9]{1,20}$"))
            {
                DeviceAtsign = "@" + DeviceAtsign;
            }
            return true;
        }

        public void PopulateAtsigns(ComboBox box)
        {
            string[] files =
            Directory.GetFiles(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys"), "*.atKeys", SearchOption.AllDirectories);
            foreach (var key in files)
            {
                ComboBoxItem item = new ComboBoxItem();
                item.Content = Path.GetFileNameWithoutExtension(key).Replace("_key", "");
                box.Items.Add(item);
            }
        }


    }
}
