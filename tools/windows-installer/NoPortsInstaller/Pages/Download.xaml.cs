using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class Download : Page
    {
        private InstallController _controller;
        public Download(InstallController installer)
        {
            InitializeComponent();
            _controller = installer;
            _controller.Install(InstallProgress, Status);
        }
    }
}
