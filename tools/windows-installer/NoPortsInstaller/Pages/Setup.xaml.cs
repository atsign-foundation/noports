using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Setup.xaml
    /// </summary>
    public partial class Setup : Page
    {
        private InstallController _controller;
        public Setup(InstallController installer)
        {
            InitializeComponent();
            _controller = installer;
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
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.DeviceInstall = DeviceInstallType.IsChecked == true;
            _controller.ClientInstall = ClientInstallType.IsChecked == true;
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
    }
}

