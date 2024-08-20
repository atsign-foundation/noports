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
        public UninstallPage(IController controller)
        {
            InitializeComponent();
            _controller = controller;
            var pages = new List<Page> { new Uninstall(controller), new FinishUninstall(controller) };
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.NextPage();
        }
    }
}
