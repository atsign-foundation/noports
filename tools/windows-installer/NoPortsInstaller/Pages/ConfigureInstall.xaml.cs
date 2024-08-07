using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class ConfigureInstall : Page
    {
        private InstallController _controller;
        public ConfigureInstall(InstallController installer)
        {
            _controller = installer;
            InitializeComponent();
        }

        private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.PreviousPage();
        }

        private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.DeviceAtsign = DeviceCombo.Text;
            _controller.ClientAtsign = ClientCombo.Text;
            _controller.DeviceName = DeviceName.Text;
            _controller.Pages.Add(new AdditionalConfiguration(_controller));
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

