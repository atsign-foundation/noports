using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class Uninstall : Page
    {
        private Installer _installer;
        public Uninstall(Installer installer)
        {
            InitializeComponent();
            _installer = installer;
            _installer.Uninstall(UninstallProgress);
        }

        private void UninstallProgress_ValueChanged(object sender, System.Windows.RoutedPropertyChangedEventArgs<double> e)
        {
            if (UninstallProgress.Value == 100)
            {
                this.Content = new FinishUninstall(_installer);
            }
        }
    }
}
