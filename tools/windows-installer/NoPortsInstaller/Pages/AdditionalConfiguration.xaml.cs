using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page2.xaml
    /// </summary>
    public partial class AdditionalConfiguration : Page
    {
        private Installer _installer;
        public AdditionalConfiguration(Installer installer)
        {
            _installer = installer;
            InitializeComponent();
            if (_installer.ClientInstall)
            {
                ClientConfig.IsEnabled = true;
            }
        }

        private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _installer.Pages.Remove(this);
            _installer.PreviousPage();
        }

        private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _installer.RegionAtsign = RegionBox.Text;
            _installer.MultipleDevices = MultipleDevices.Text;
            _installer.Pages.Add(new Download(_installer));
            _installer.NextPage();
            _installer.Pages.Add(new FinishInstall(_installer));
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
