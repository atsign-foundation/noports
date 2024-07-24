using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller
{
    /// <summary>
    /// Interaction logic for Setup.xaml
    /// </summary>
    public partial class Setup : Page
    {
        private Installer _installer;
        public Setup(Installer installer)
        {
            InitializeComponent();
            _installer = installer;
        }

        private void OpenDialogButton_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new Microsoft.Win32.OpenFolderDialog();
            dialog.InitialDirectory = _installer.InstallDirectory;

            // Process save file dialog box results
            if (dialog.ShowDialog() == true)
            {
                _installer.InstallDirectory = dialog.FolderName + "\\NoPorts";
            }
            Directory.Text = _installer.InstallDirectory;

        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            _installer.DeviceInstall = DeviceInstallType.IsChecked == true;
            _installer.ClientInstall = ClientInstallType.IsChecked == true;
            _installer.NextPage();
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

