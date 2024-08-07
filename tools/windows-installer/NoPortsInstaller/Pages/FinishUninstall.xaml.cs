using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for FinishInstall.xaml
    /// </summary>
    public partial class FinishUninstall : Page
    {
        private InstallController _controller;
        public FinishUninstall(InstallController installer)
        {
            InitializeComponent();
            _controller = installer;
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}
