using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for UninstallPage.xaml
    /// </summary>
    public partial class UninstallPage : Page
    {
        private readonly IController _controller;
        public UninstallPage()
        {
            InitializeComponent();
            _controller = App.ControllerInstance;
            var pages = new List<Page> { new Uninstall(), new FinishUninstall() };
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.NextPage();
        }
    }
}
