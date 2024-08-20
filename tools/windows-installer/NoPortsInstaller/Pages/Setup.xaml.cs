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
        public Setup(IController installer)
        {
            InitializeComponent();
            _controller = installer;
            if (_controller.IsInstalled)
            {
                UpdateConfig.IsEnabled = true;
            }
        }

        private void OpenDialogButton_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.OpenFolderDialog();
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
    }
}

