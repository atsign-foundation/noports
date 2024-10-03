using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using static NoPortsInstaller.ActivateController;

namespace NoPortsInstaller.Pages.Activate
{
    /// <summary>
    /// Interaction logic for PreEnroll.xaml
    /// </summary>
    public partial class PreEnroll : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        private readonly Process at_activate = new();
        public PreEnroll()
        {
            InitializeComponent();
            at_activate.StartInfo.FileName = Path.Combine(_controller.InstallDirectory, "at_activate.exe");
            at_activate.StartInfo.Arguments = $"onboard -a ";
            at_activate.StartInfo.UseShellExecute = false;
            at_activate.StartInfo.RedirectStandardOutput = true;
            at_activate.StartInfo.RedirectStandardInput = true;
            at_activate.StartInfo.RedirectStandardError = true;
            at_activate.StartInfo.CreateNoWindow = true;
        }

        private void BackPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.PreviousPage();
            _controller.LoadPages(InstallType.Home);
        }
        // Event handler for TextChanged
        

        private static bool IsProcessReady(Process process)
        {
            // Check if the process has started and is ready to receive input
            return process.StandardInput.BaseStream.CanWrite;
        }


        private void Next_Click(object sender, RoutedEventArgs e)
		{
			ActivateResponseText.Visibility = Visibility.Hidden;
			ActivateResponseText.Content = "";
			_controller.DeviceAtsign = _controller.NormalizeAtsign(Atsign.Text);
            var response = ActivateController.Status(_controller.DeviceAtsign);
            if (response != AtsignStatus.NotActivated && response != AtsignStatus.Activated)
			{
				ActivateResponseText.Content = "This atsign does not exist.";
				ActivateResponseText.Visibility = Visibility.Visible;
			}
            else
			{
				_controller.NextPage();
			}
		}

		private void Atsign_TextChanged(object sender, TextChangedEventArgs e)
		{
            if (Atsign.Text.Length > 0)
            {
				ActivateResponseText.Visibility = Visibility.Visible;
			}
			else
			{
				ActivateResponseText.Visibility = Visibility.Hidden;
			}
		}
	}
}
