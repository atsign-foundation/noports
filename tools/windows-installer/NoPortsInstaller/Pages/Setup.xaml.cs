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
        private readonly Controller _controller;

		public Setup()
        {
            InitializeComponent();
			_controller = App.ControllerInstance;
			AccessGroupText.Text = _controller.AccessGroup;
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
        }

        private void DeviceInstall_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Device);
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
            _controller.NextPage();
        }

		private void Enroll_Click(object sender, RoutedEventArgs e)
		{
            _controller.LoadPages(InstallType.Enroll);
            _controller.NextPage();
		}

		private void Otp_Click(object sender, RoutedEventArgs e)
		{
			_controller.LoadPages(InstallType.Approve);
			_controller.NextPage();
		}

		private void AccessGroupText_TextChanged(object sender, TextChangedEventArgs e)
		{
            InstallLogger.Log(AccessGroupText.Text);
            InstallLogger.DumpLog();
            _controller.AccessGroup = AccessGroupText.Text;
        }
    }
}

