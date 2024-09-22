using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Install
{
    /// <summary>
    /// Interaction logic for Page2.xaml
    /// </summary>
    public partial class DeviceConfig : Page
    {
        private readonly IController _controller;
        public DeviceConfig()
        {
            _controller = App.ControllerInstance;
            InitializeComponent();
        }

        private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.PreviousPage();
        }

        private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.AdditionalArgs = _controller.NormalizeArgs(AdditionalArgs.Text);
            _controller.Pages.Add(new Download());
            _controller.NextPage();
        }
    }
}
