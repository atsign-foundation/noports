using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page2.xaml
    /// </summary>
    public partial class AdditionalConfiguration : Page
    {
        private InstallController _controller;
        public AdditionalConfiguration(InstallController installer)
        {
            _controller = installer;
            InitializeComponent();
            if (_controller.ClientInstall)
            {
                ClientConfig.IsEnabled = true;
            }
        }

        private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.Pages.Remove(this);
            _controller.PreviousPage();
        }

        private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.RegionAtsign = RegionBox.Text;
            _controller.MultipleDevices = MultipleDevices.Text;
            _controller.Pages.Add(new Download(_controller));
            _controller.NextPage();
        }

        private void ValidateInputs()
        {
            if (RegionBox.Text == "")
            {
                NextPageButton.IsEnabled = false;
            }
            else
            {
                NextPageButton.IsEnabled = true;
            }
        }
    }
}
