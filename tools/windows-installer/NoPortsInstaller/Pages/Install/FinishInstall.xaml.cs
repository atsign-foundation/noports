using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Install
{
    /// <summary>
    /// Interaction logic for FinishInstall.xaml
    /// </summary>
    public partial class FinishInstall : Page
    {
        public FinishInstall()
        {
            InitializeComponent();
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            InstallLogger.DumpLog();
            Application.Current.Shutdown();
        }
    }
}
