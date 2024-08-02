using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class Download : Page
    {
        private Installer _installer;
        public Download(Installer installer)
        {
            InitializeComponent();
            _installer = installer;
            _installer.Install(InstallProgress);
        }
    }
}
