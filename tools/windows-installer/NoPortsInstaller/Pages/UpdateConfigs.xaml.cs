using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for UpdateConfigs.xaml
    /// </summary>
    public partial class UpdateConfigs : Page
    {
        private readonly IController _controller;
        public UpdateConfigs(IController controller)
        {
            InitializeComponent();
            _controller = controller;
        }

        private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.DeviceAtsign = DeviceCombo.Text;
            _controller.ClientAtsign = ClientCombo.Text;
            _controller.DeviceName = DeviceName.Text;
            _controller.UpdateConfigRegistry();
            _controller.Pages.Add(new FinishInstall(_controller));
            _controller.NextPage();
        }

        private void ClientCombo_Initialized(object sender, EventArgs e)
        {
            ComboBox comboBox = (ComboBox)sender;
            _controller.PopulateAtsigns(comboBox);
        }

        private void DeviceCombo_Initialized(object sender, EventArgs e)
        {
            ComboBox comboBox = (ComboBox)sender;
            _controller.PopulateAtsigns(comboBox);
        }

        private void ValidateInputs()
        {
            if (ClientCombo.Text == "" || DeviceCombo.Text == "" || DeviceName.Text == "")
            {
                NextPageButton.IsEnabled = false;
            }
            else
            {
                NextPageButton.IsEnabled = true;
            }
        }

        private void ClientCombo_FocusableChanged(object sender, System.Windows.DependencyPropertyChangedEventArgs e)
        {
            ValidateInputs();
        }

        private void DeviceCombo_FocusableChanged(object sender, System.Windows.DependencyPropertyChangedEventArgs e)
        {
            ValidateInputs();
        }

        private void DeviceName_TextChanged(object sender, TextChangedEventArgs e)
        {
            ValidateInputs();
        }
    }
}
