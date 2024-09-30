using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Update
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class Uninstall : Page
    {
        private readonly Controller _controller;
        public Uninstall()
        {
            InitializeComponent();
            _controller = App.ControllerInstance;
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
