using Microsoft.Win32;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Security.AccessControl;
using System.Text.Json;
using System.Text.RegularExpressions;
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
        }

        public async void Install(ProgressBar progress)
        {
            CreateDirectories(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile));
            UpdateProgress(progress, 25);
            await DownloadArchive();
            UpdateProgress(progress, 50);
            ExtractArchive();
            UpdateProgress(progress, 90);
            CreateRegistryKeys();
            if (DeviceInstall)
            {
                CopyIntoServiceAccount();
                SetupService();
            }
            UpdateProgress(progress, 100);
            NextPage();
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
                catch (Exception ex)
                {
                    Console.WriteLine($"An error occurred while copying {sources[i]} to {destinations[i]}: {ex.Message}");
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
                Console.WriteLine($"An error occurred while downloading the archive: {ex.Message}");
            }

            return;
        }

        private void ExtractArchive()
        {
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

        private void SetupService()
        {
            if (!EventLog.SourceExists("NoPorts"))
            {
                EventLog.CreateEventSource("NoPorts", "NoPorts");
            }


            if (ServiceInstaller.ServiceIsInstalled("sshnpd"))
            {
                ServiceInstaller.StopService("sshnpd");
                ServiceInstaller.Uninstall("sshnpd");
            }
            ServiceInstaller.InstallAndStart("sshnpd", "sshnpd", InstallDirectory + @"\SshnpdService.exe");
            //ServiceInstaller.CreateUninstaller(System.AppDomain.CurrentDomain.BaseDirectory + @"NoPortsInstaller.exe");
            //ServiceInstaller.EnableRecovery("sshnpd");
            Process.Start("sc", "description sshnpd NoPorts SSH Daemon");
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

        private void CreateConfigFile()
        {
            // Not Implemented
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

        public void Setup(MainWindow window)
        {
            this.window = window;
            window.Content = Pages[0];
        }

        private void UpdateProgress(ProgressBar pb, int value)
        {
            for (int i = 0; i < value; i++)
            {
                pb.Value = i;
                Thread.Sleep(10);
            }
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
