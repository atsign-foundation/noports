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

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.Pages.RemoveRange(1, _controller.Pages.Count - 1);
            if (ClientInstallType.IsChecked == true && DeviceInstallType.IsChecked == true)
            {
                _controller.InstallType = InstallType.Both;
            }
            else if (DeviceInstallType.IsChecked == true)
            {
                _controller.InstallType = InstallType.Device;
            }
            else
            {
                _controller.InstallType = InstallType.Client;
            }
            _controller.LoadPages();
            _controller.NextPage();
        }

        private void EnableButton()
        {

            if (DeviceInstallType.IsChecked == true || ClientInstallType.IsChecked == true)
            {
                NextPageButton.IsEnabled = true;
            }
            else
            {
                NextPageButton.IsEnabled = false;
            }
        }

        private void DeviceInstallType_Click(object sender, RoutedEventArgs e)
        {
            EnableButton();
        }

        private void ClientInstallType_Click(object sender, RoutedEventArgs e)
        {
            EnableButton();
        }

        private void UpdateConfigButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.InstallType = InstallType.Update;
            _controller.LoadPages();
            _controller.NextPage();
        }

        private void AtKeyButton_Click(object sender, RoutedEventArgs e)
        {
            OpenFileDialog dialog = new();
            dialog.InitialDirectory = _controller.InstallDirectory;
            if (dialog.ShowDialog() == true)
            {
                _controller.AtkeysPath = dialog.FileName;
            }
        }
    }
}

