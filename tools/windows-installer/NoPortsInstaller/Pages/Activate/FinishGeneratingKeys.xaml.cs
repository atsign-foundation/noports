using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Activate
{
    /// <summary>
    /// Interaction logic for FinishGeneratingKeys.xaml
    /// </summary>
    public partial class FinishGeneratingKeys : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        public FinishGeneratingKeys()
        {
            InitializeComponent();
        }

        private void HomeButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Home);
            _controller.NextPage();
        }

    }
}
