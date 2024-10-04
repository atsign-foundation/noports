using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Install
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class Download : Page
    {
        private readonly Controller _controller;
        public Download()
        {
            InitializeComponent();
            _controller = App.ControllerInstance;
			_ = _controller.Install(InstallProgress, Status);
        }

		private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
		{
            _controller.PreviousPage();
		}
	}
}
