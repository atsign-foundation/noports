using Microsoft.Win32;
using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Setup.xaml
    /// </summary>
    public partial class Setup : Page
    {
        private readonly IController _controller;
        public Setup()
        {
            InitializeComponent();
            _controller = App.ControllerInstance;
            if (_controller.IsInstalled)
            {
                UpdateConfig.IsEnabled = true;
            }
        }

        private void OpenDialogButton_Click(object sender, RoutedEventArgs e)
        {
            OpenFolderDialog dialog = new();
            dialog.InitialDirectory = _controller.InstallDirectory;

            // Process save file dialog box results
            if (dialog.ShowDialog() == true)
            {
                _controller.InstallDirectory = dialog.FolderName + "\\NoPorts";
            }
            Directory.Text = _controller.InstallDirectory;
            if (_controller.IsInstalled)
            {
                UpdateConfig.IsEnabled = true;
            }
        }

        private void DeviceInstall_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Device);
            _controller.NextPage();
        }

        private void UpdateConfigButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Update);
            _controller.NextPage();
        }

        private void ClientInstall_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Client);
            _controller.NextPage();
        }

        private void Onboard_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Onboard);
            _controller.Onboard();
        }

        private void Enroll_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Enroll);
            _controller.Enroll();
        }
    }
}

