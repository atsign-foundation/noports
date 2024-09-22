using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Update
{
    /// <summary>
    /// Interaction logic for FinishInstall.xaml
    /// </summary>
    public partial class FinishUninstall : Page
    {
        public FinishUninstall()
        {
            InitializeComponent();
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}
