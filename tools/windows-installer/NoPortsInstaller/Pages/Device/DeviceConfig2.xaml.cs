using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Install
{
    /// <summary>
    /// Interaction logic for Page2.xaml
    /// </summary>
    public partial class DeviceConfig2 : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        public DeviceConfig2()
        {
            InitializeComponent();
        }

        private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.PreviousPage();
        }

        private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.AdditionalArgs = _controller.NormalizeArgs(AdditionalArgs.Text);
            _controller.Enroll();
            _controller.NextPage();
        }
    }
}
