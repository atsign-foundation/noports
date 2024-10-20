using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Install
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class InstallService : Page
    {
        private readonly Controller _controller;
        public InstallService()
        {
            InitializeComponent();
            _controller = App.ControllerInstance;
			_ = _controller.InstallService(InstallProgress, Status);
        }
    }
}
