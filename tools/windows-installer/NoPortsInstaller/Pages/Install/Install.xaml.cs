using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Install
{
    /// <summary>
    /// Interaction logic for FinishInstall.xaml
    /// </summary>
    public partial class Install : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        public Install(string message)
        {
            InitializeComponent();
            MessageLabel.Content = message;
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.Pages.Add(new Download());
            _controller.NextPage();
        }
    }
}
