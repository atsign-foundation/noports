using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Activate
{
    /// <summary>
    /// Interaction logic for Enroll.xaml
    /// </summary>
    public partial class AtsignApprove : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        public AtsignApprove()
        {
            InitializeComponent();
        }


        private void BackPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Home);
        }

        private void AtsignCombo_Initialized(object sender, EventArgs e)
        {
            ComboBox comboBox = (ComboBox)sender;
            _controller.PopulateAtsigns(comboBox);
        }

        private void Next_Click(object sender, RoutedEventArgs e)
        {
            if (AtsignCombo.Text != "")
            {
                try
                {
                    var atsign = _controller.NormalizeAtsign(AtsignCombo.Text);
                    if (ActivateController.CheckIfMPKAM(atsign))
                    {
                        _controller.DeviceAtsign = _controller.NormalizeAtsign(AtsignCombo.Text);
                        _controller.Pages.Add(new Approve());
                        _controller.Pages.Add(new FinishGeneratingKeys());
                        _controller.NextPage();
                    }
                }
                catch
                {
                    _controller.LoadError(new Exception("Failed to find MPKAM Keys for the given atsign"));
                }
            }
        }
    }
}
