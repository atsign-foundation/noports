using NoPortsInstaller.Pages.Install;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Update
{
    /// <summary>
    /// Interaction logic for Page2.xaml
    /// </summary>
    public partial class UpdateDevice : Page
    {
        private readonly IController _controller;
        public UpdateDevice()
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
            if (AdditionalArgs.Text != "")
            {
                _controller.AdditionalArgs = AdditionalArgs.Text;
            }
            _controller.UpdateConfigRegistry();
            _controller.Pages.Add(new FinishInstall());
            _controller.NextPage();
        }
    }
}
