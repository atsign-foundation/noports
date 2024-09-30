using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Update
{
    /// <summary>
    /// Interaction logic for UninstallPage.xaml
    /// </summary>
    public partial class UninstallPage : Page
    {
        private readonly Controller _controller;
        public UninstallPage()
        {
            InitializeComponent();
            _controller = App.ControllerInstance;
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.Pages.Add(new Uninstall());
            _controller.Pages.Add(new FinishUninstall());
            _controller.NextPage();
        }
    }
}
