using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    /// <summary>
    /// Interaction logic for Page1.xaml
    /// </summary>
    public partial class ConfigureInstall : Page
    {
        private Installer _installer;
        public ConfigureInstall(Installer installer)
        {
            _installer = installer;
            InitializeComponent();
        }

        private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _installer.PreviousPage();
        }

        private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _installer.DeviceAtsign = DeviceCombo.Text;
            _installer.ClientAtsign = ClientCombo.Text;
            _installer.DeviceName = DeviceName.Text;
            _installer.Pages.Add(new AdditionalConfiguration(_installer));
            _installer.NextPage();
        }

        private void ClientCombo_Initialized(object sender, EventArgs e)
        {
            ComboBox comboBox = (ComboBox)sender;
            _installer.PopulateAtsigns(comboBox);
        }

        private void DeviceCombo_Initialized(object sender, EventArgs e)
        {
            ComboBox comboBox = (ComboBox)sender;
            _installer.PopulateAtsigns(comboBox);
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

