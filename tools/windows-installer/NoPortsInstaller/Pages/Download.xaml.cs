using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class Download : Page
    {
        private readonly IController _controller;
        public Download()
        {
            InitializeComponent();
            _controller = App.ControllerInstance;
            _controller.Install(InstallProgress, Status);
        }
    }
}
