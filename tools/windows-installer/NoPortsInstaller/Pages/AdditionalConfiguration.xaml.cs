using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page2.xaml
    /// </summary>
    public partial class AdditionalConfiguration : Page
    {
        private readonly IController _controller;
        public AdditionalConfiguration()
        {
            _controller = App.ControllerInstance;
            InitializeComponent();
            if (_controller.InstallType.Equals(InstallType.Client))
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
            _controller.RegionAtsign = _controller.NormalizeAtsign(RegionBox.Text);
            _controller.MultipleDevices = MultipleDevices.Text;
            _controller.Pages.Add(new Download());
            _controller.NextPage();
        }
    }
}
