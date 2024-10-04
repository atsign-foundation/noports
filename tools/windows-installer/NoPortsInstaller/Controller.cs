using Microsoft.Win32;
using NoPortsInstaller.Pages;
using NoPortsInstaller.Pages.Activate;
using NoPortsInstaller.Pages.Install;
using NoPortsInstaller.Pages.Update;
using System.Diagnostics;
using System.IO;
using System.Security.AccessControl;
using System.Windows;
using System.Windows.Controls;
using static NoPortsInstaller.ActivateController;

namespace NoPortsInstaller
{
    public class Controller
    {
        public string InstallDirectory { get; set; }
        public InstallType InstallType { get; set; }
        public string ClientAtsign { get; set; }
        public string DeviceAtsign { get; set; }
        public string DeviceName { get; set; }
        public string RegionAtsign { get; set; }
        public string AdditionalArgs { get; set; }
        public bool IsInstalled
        {
            get { return Directory.Exists(InstallDirectory); }
            set { }
        }

        public bool IsActivateInstalled
        {
            get { return Directory.Exists(InstallDirectory) && File.Exists(InstallDirectory + "/at_activate.exe"); }
            set { }
        }
        public List<Page> Pages { get; set; }
        private int index = 0;
        private readonly string serviceDirectory =
                Environment.ExpandEnvironmentVariables("%systemroot%")
                + @"\ServiceProfiles\LocalService\";
        public Window? Window { get; set; }
        public AccessRules AccessRules { get; set; }

        public string AtsignKeysDirectory
        {
            get
            {
                return Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                    @".atsign\keys"
                );
            }
        }

        public Controller()
        {
            InstallDirectory = "C:\\Program Files\\NoPorts";
            InstallType = InstallType.Home;
            ClientAtsign = "";
            DeviceAtsign = "";
            DeviceName = "";
            RegionAtsign = "";
            AdditionalArgs = "";
            Pages = [];
            IsInstalled = false;
            LogEnvironment();
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
                await UpdateProgressBar(progress, 100);
                InstallLogger.Log($"Installation Complete");
				if (InstallType.Equals(InstallType.Client))
				{
					Pages.Add(new FinishInstall());
				}
                if (InstallType.Equals(InstallType.Device))
                {
                    EnrollDevice();
                }
				NextPage();
			}
			catch (Exception ex)
            {
                await Cleanup();
                LoadError(ex);
            }
        }

        public async Task InstallService(ProgressBar progress, Label status)
        {
			try
			{
				await UpdateProgressBar(progress, 25);
				status.Content = "Setting up NoPorts Service...";
				CopyIntoServiceAccount();
				await SetupService(status);
				await UpdateProgressBar(progress, 100);
				NextPage();
			}
			catch (Exception ex)
			{
				await Cleanup();
				LoadError(ex);
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
                    Registry.LocalMachine.DeleteSubKey(
                        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\NoPorts"
                    );
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
                LoadError(ex);
            }
        }

        /// <summary>
        /// will change
        /// </summary>
        public void EnrollDevice()
        {
			if (!KeysInstalled())
			{
				if (ActivateController.Status(DeviceAtsign) != AtsignStatus.Activated)
				{
					throw new Exception("Keys not found locally and on registrar. Please onboard first.");
				}

				InstallLogger.Log("Starting enrollment process before continuing to install...");
				Pages.Add(new Enroll());
			}
			else
			{
				InstallLogger.Log("Keys found. Continuing to service install...");
				Pages.Add(new InstallService());
				Pages.Add(new FinishInstall());
			}
		}

		public void UpdateConfigRegistry()
        {
            try
            {
                RegistryKey? registryKey = Registry.LocalMachine.OpenSubKey(@"Software\NoPorts");
                var args = $"-a {DeviceAtsign} -m {ClientAtsign} -d {DeviceName} -sv";
                if (registryKey != null)
                {
                    if (AdditionalArgs != "")
                    {
                        args += AdditionalArgs;
                    }
                    registryKey.SetValue("DeviceArgs", args);
                    registryKey.Close();
                }
            }
            catch (Exception ex)
            {
                LoadError(ex);
            }
        }

        private void CreateDirectories(string userHome)
        {
            DirectorySecurity securityRules = new();
            DirectoryInfo di;
            securityRules.AddAccessRule(
                new FileSystemAccessRule("Users", FileSystemRights.Modify, AccessControlType.Allow)
            );
            List<string> directories =
            [
                Path.Combine(userHome, ".sshnp"),
                Path.Combine(userHome, ".atsign"),
                Path.Combine(userHome, ".atsign", "keys"),
                InstallDirectory,
            ];

            if (InstallType.Equals(InstallType.Device))
            {
                directories.Add(Path.Combine(userHome, ".ssh"));
            }

            foreach (string dir in directories)
            {
                if (!Directory.Exists(dir))
                {
                    InstallLogger.Log($"Creating directory: {dir}");
                    Directory.CreateDirectory(dir);
                    di = new DirectoryInfo(dir);
                    di.SetAccessControl(securityRules);
                }
                else
                {
                    InstallLogger.Log($"Directory already exists, skipping: {dir}");
                }
            }
            if (InstallType.Equals(InstallType.Device))
            {
                var authkeys = Path.Combine(userHome, ".ssh", "authorized_keys");
                InstallLogger.Log($"Creating authorized_keys file: {authkeys}");
                if (!File.Exists(authkeys))
                {
                    FileInfo fi = new(authkeys);
                    fi.Create().Close();
                }
            }
        }

        private void CopyIntoServiceAccount()
        {
            string sourceFile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string[] sources =
            [
                Path.Combine(sourceFile, ".ssh", "authorized_keys"),
                Path.Combine(sourceFile, ".atsign", "keys", DeviceAtsign + "_key.atKeys"),
            ];
            InstallLogger.Log($"Creating Directories in LocalService Account: {serviceDirectory}");
            CreateDirectories(serviceDirectory);
            string[] destinations =
            [
                Path.Combine(serviceDirectory, ".ssh", "authorized_keys"),
                Path.Combine(serviceDirectory, ".atsign", "keys", DeviceAtsign + "_key.atKeys"),
            ];
            for (int i = 0; i < sources.Length; i++)
            {
                try
                {
                    if (File.Exists(sources[i]))
                    {
                        InstallLogger.Log($"Copying {sources[i]} to {destinations[i]}");
                        File.Copy(sources[i], destinations[i], true);
                    }
                }
                catch
                {
                    throw new FileNotFoundException(
                        "No keys found. Use at_activate to onboard keys or enroll/approve this device."
                    );
                }
            }
        }

        private async Task MoveResources()
        {
            Dictionary<byte[], string> resources =
                new()
                {
                    { Properties.Resources.at_activate, "at_activate.exe" },
                };

            if (InstallType.Equals(InstallType.Device) || InstallType.Equals(InstallType.Client))
            {
                resources.Add(Properties.Resources.srv, "srv.exe");
            }
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

            foreach (var resource in resources)
            {
                string path = Path.Combine(InstallDirectory, resource.Value);
                if (Directory.Exists(InstallDirectory))
                {
                    InstallLogger.Log($"placing resource: {resource.Value} into {path}");
                    await Task.Run(() => File.WriteAllBytes(path, resource.Key));
                }
                else
                {
                    throw new Exception("Install directory does not exist.");
                }
            }
            InstallLogger.Log("Adding NoPorts to PATH...");
            var newValue =
                Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.Machine)
                + ";"
                + InstallDirectory;
            Environment.SetEnvironmentVariable("PATH", newValue, EnvironmentVariableTarget.Machine);
        }

        private async Task SetupService(Label status)
        {
            if (!EventLog.SourceExists("NoPorts"))
            {
                InstallLogger.Log("Makign Event Logger for NoPorts");
                EventLog.CreateEventSource("NoPorts", "NoPorts");
            }

            try
            {
                InstallLogger.Log("Installing sshnpd service...");
                status.Content = "Installing sshnpd service...";
                await Task.Run(
                    () =>
                        ServiceController.InstallAndStart(
                            "sshnpd",
                            "sshnpd",
                            InstallDirectory + @"\SshnpdService.exe"
                        )
                );
                InstallLogger.Log($"sshnpd for {DeviceAtsign} at {DeviceName} is now running.");
                InstallLogger.Log("Setting service options for sshnpd...");
                status.Content = "Configuring the Windows Service...";
                await Task.Run(() => ServiceController.SetRecoveryOptions("sshnpd"));
                Process.Start("sc", "description sshnpd NoPorts-SSH-Daemon");
                await Task.Run(
                    () =>
                        ServiceController.CreateUninstaller(
                            Path.Combine(
                                Path.GetDirectoryName(Environment.ProcessPath)!,
                                "NoPortsInstaller.exe u"
                            )
                        )
                );
            }
            catch
            {
                throw;
            }
            return;
        }

        private static void UpdateTrustedCerts()
        {
            var tempPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                @"Temp\trusted-certs"
            );
            if (!Directory.Exists(tempPath))
            {
                Directory.CreateDirectory(tempPath);
            }
            tempPath += @"\roots.sst";
            InstallLogger.Log("Generating certificates...");
            ProcessStartInfo startInfo =
                new()
                {
                    FileName = "Certutil.exe",
                    Arguments = $"-generateSSTFromWU {tempPath}",
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                };

            using (Process? process = Process.Start(startInfo))
            {
                process?.WaitForExit();
            }
            InstallLogger.Log("Importing certificates...");
            startInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Verb = "runas",
                Arguments =
                    $"-WindowStyle Hidden -Command \"(Get-ChildItem '{tempPath}') | Import-Certificate -CertStoreLocation Cert:\\LocalMachine\\Root\"",
                UseShellExecute = true,
                CreateNoWindow = true,
            };

            using (Process? process = Process.Start(startInfo))
            {
                process?.WaitForExit();
            }
        }

        private void CreateRegistryKeys()
        {
            InstallLogger.Log("Creating registry keys...");
            RegistryKey registryKey = Registry.LocalMachine.CreateSubKey(@"Software\NoPorts");
            registryKey.SetValue("BinPath", InstallDirectory);
            if (InstallType.Equals(InstallType.Device))
            {
                var args = $"-a {DeviceAtsign} -m {ClientAtsign} -d {DeviceName}";
                if (AdditionalArgs != "")
				{
					args += AdditionalArgs;
				}

				args += " -v";
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
                    Directory.Delete(
                        Path.Combine(
                            Environment.GetFolderPath(
                                Environment.SpecialFolder.LocalApplicationData
                            ),
                            @"Temp\NoPorts"
                        ),
                        true
                    );
                    RegistryKey? registryKey = Registry.LocalMachine.OpenSubKey(
                        @"SOFTWARE\NoPorts"
                    );
                    if (registryKey != null)
                    {
                        registryKey.DeleteValue("BinPath");
                        registryKey.DeleteValue("DeviceArgs");
                        registryKey.Close();
                    }
                }
                catch { }
            });
        }

        /// <summary>
        /// Loads the appropriate pages based on the InstallType.
        /// </summary>
        public void LoadPages(InstallType type)
        {
            InstallType = type;
            index = 0;
            Pages.Clear();
            switch (InstallType)
            {
                case InstallType.Home:
                    InstallLogger.DumpLog();
                    Pages.Add(new Setup());
                    break;
                case InstallType.Uninstall:
                    Pages.Add(new UninstallPage());
                    break;
                case InstallType.Client:
                    Pages.Add(new Setup());
                    Pages.Add(new ClientConfig());
                    break;
                case InstallType.Device:
                    Pages.Add(new Setup());
                    Pages.Add(new DeviceConfig1());
                    Pages.Add(new DeviceConfig2());
                    break;
                case InstallType.Enroll:
                    Pages.Add(new Setup());
                    if(!IsActivateInstalled)
                    {
                        Pages.Add(new Download());
                    }
                    Pages.Add(new PreEnroll());
                    break;
                case InstallType.Onboard:
                    Pages.Add(new Setup());
                    if(!IsActivateInstalled)
                    {
                        Pages.Add(new Download());
                    }
                    Pages.Add(new Onboard());
                    Pages.Add(new FinishGeneratingKeys());
                    break;
                case InstallType.Approve:
					Pages.Add(new Setup());
					if (!IsActivateInstalled)
					{
						Pages.Add(new Download());
                    }
                    Pages.Add(new AtsignApprove());
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

        public void LoadError(Exception ex)
        {
            index = 0;
            Pages.Clear();
            InstallLogger.Log($"Error message: {ex.Message}");
            InstallLogger.Log($"Error trace: {ex.StackTrace}");
            InstallLogger.DumpLog();
            Pages.Add(new ServiceErrorPage(ex.Message));
            NextPage();
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
            if (
                Directory.Exists(
                    Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                        @".atsign\keys"
                    )
                )
            )
            {
                files =
                [
                    .. Directory.GetFiles(
                        Path.Combine(
                            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                            @".atsign\keys"
                        ),
                        "*.atKeys",
                        SearchOption.AllDirectories
                    ),
                ];
            }
            foreach (var key in files)
            {
                ComboBoxItem item =
                    new() { Content = Path.GetFileNameWithoutExtension(key).Replace("_key", "") };
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

        public string NormalizeArgs(string args)
        {
            string[] argArray = args.Split(args, ' ');
            for (int i = 0; i < argArray.Length; i++)
            {
                if (argArray[i].Equals("--managers"))
                {
                    argArray[i + 1] = NormalizeMultipleManagers(argArray[i + 1]);
                }
                if (argArray[i].Equals("--po"))
                {
                    argArray[i + 1] = NormalizePermittedPorts(argArray[i + 1]);
                }
            }
            return string.Join(' ', argArray);
        }

        private string NormalizeMultipleManagers(string atsigns)
        {
            string[] atsignArray = atsigns.Split(',');
            for (int i = 0; i < atsignArray.Length; i++)
            {
                atsignArray[i] = NormalizeAtsign(atsignArray[i]);
            }
            return string.Join(',', atsignArray);
        }

        private static string NormalizePermittedPorts(string ports)
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

        public string NormalizeDeviceName(string device)
        {
            if (device.Contains(' ') || device.Contains('-'))
            {
                return device.ToLower().Replace(" ", "_");
            }
            return device.ToLower();
        }

        public void VerifyInstall()
        {
            List<String> dirs = ["at_activate.exe"];
            if(InstallType == InstallType.Client || InstallType == InstallType.Device )
            {
                dirs.Add("srv.exe");
			}
			if (InstallType == InstallType.Client)
			{
                dirs.Add("sshnp.exe");
                dirs.Add("npt.exe");
			}
			if (InstallType == InstallType.Device)
			{
                dirs.Add("sshnpd.exe");
                dirs.Add("Sshnpd.exe");
            }
            foreach (var dir in dirs)
            {
                string sourceFilePath = Path.Combine(InstallDirectory, dir);
                if (!File.Exists(sourceFilePath))
                {
                    throw new Exception("File not found: " + sourceFilePath);
                }
            }
        }

        private bool KeysInstalled()
        {
            return File.Exists(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys", DeviceAtsign + "_key.atKeys"));
        }

        private static void LogEnvironment()
        {
            InstallLogger.Log("Environment Variables:");
            InstallLogger.Log(
                $"User Home: {Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)}"
            );
            InstallLogger.Log(
                $"Program Files: {Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles)}"
            );
            InstallLogger.Log(
                $"Local App Data: {Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)}"
            );
            InstallLogger.Log(
                $"LocalService: {Environment.ExpandEnvironmentVariables("%systemroot%") + @"\ServiceProfiles\LocalService\"}"
            );
            try
            {
                Directory.CreateDirectory(
                    Environment.ExpandEnvironmentVariables("%systemroot%") + @"\ServiceProfiles\LocalService\" + @"\.atsign"
                );
                InstallLogger.Log("Created .atsign directory in LocalService.");
            }
            catch
            {
                InstallLogger.Log("Failed to create .atsign directory in LocalService Account.");
            }

            InstallLogger.Log("User Information:");
            InstallLogger.Log($"Username: {Environment.UserName}");
            InstallLogger.Log($"Domain: {Environment.UserDomainName}");

            InstallLogger.Log("Operating System Information:");
            InstallLogger.Log($"OS Version: {Environment.OSVersion}");
            InstallLogger.Log($"Machine Name: {Environment.MachineName}");
            InstallLogger.Log($"System Directory: {Environment.SystemDirectory}");
            InstallLogger.Log($"Is 64-bit Operating System: {Environment.Is64BitOperatingSystem}");
            InstallLogger.Log($"Is 64-bit Process: {Environment.Is64BitProcess}");

            InstallLogger.Log("Process Information:");
            InstallLogger.Log($"Process Path: {Environment.ProcessPath}");
            InstallLogger.Log($"Process is run as Admin: {Environment.IsPrivilegedProcess}");
            InstallLogger.Log($"Runtime Version:{Environment.Version}");
        }
    }
}
