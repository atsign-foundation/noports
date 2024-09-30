using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Install
{
    /// <summary>
    /// Interaction logic for Page2.xaml
    /// </summary>
    public partial class ClientConfig : Page
    {
        private readonly Controller _controller;
        public ClientConfig()
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
            _controller.Pages.Add(new Download());
            _controller.NextPage();
        }
    }
}
