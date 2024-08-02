using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for ServiceErrorPage.xaml
    /// </summary>
    public partial class ServiceErrorPage : Page
    {
        public ServiceErrorPage()
        {
            InitializeComponent();
        }

        private void NextPageButton_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}
