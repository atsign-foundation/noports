using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller
{
    /// <summary>
    /// Interaction logic for FinishInstall.xaml
    /// </summary>
    public partial class FinishInstall : Page
    {
        private Installer _installer;
        public FinishInstall(Installer installer)
        {
            InitializeComponent();
            _installer = installer;
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}
