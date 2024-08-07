using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class Uninstall : Page
    {
        private InstallController _controller;
        public Uninstall(InstallController installer)
        {
            InitializeComponent();
            _controller = installer;
            _controller.Uninstall(UninstallProgress);
        }

        private void UninstallProgress_ValueChanged(object sender, System.Windows.RoutedPropertyChangedEventArgs<double> e)
        {
            if (UninstallProgress.Value == 100)
            {
                _controller.NextPage();
            }
        }
    }
}
