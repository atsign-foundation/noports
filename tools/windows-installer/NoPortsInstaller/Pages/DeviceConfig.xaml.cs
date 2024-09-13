using System.Windows.Controls;

namespace NoPortsInstaller.Pages
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
            if (MultipleManagers.Text != "")
            {
                _controller.MultipleManagers = _controller.NormalizeMultipleManagers(MultipleManagers.Text);
            }
            if (PermittedPorts.Text != "")
            {
                _controller.PermittedPorts = _controller.NormalizePermittedPorts(PermittedPorts.Text);
            }
            _controller.Pages.Add(new Download());
            _controller.NextPage();
        }
    }
}
