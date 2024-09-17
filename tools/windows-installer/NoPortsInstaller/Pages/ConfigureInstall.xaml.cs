﻿using System.IO;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages
{
    public partial class ConfigureInstall : Page
    {
        private readonly IController _controller;
        public ConfigureInstall()
        {
            _controller = App.ControllerInstance;
            if (!Directory.Exists(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys")))
            {
                Directory.CreateDirectory(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".atsign\keys"));
            }
            _controller.MoveUploadedAtkeys();
            InitializeComponent();
        }

        private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.PreviousPage();
        }

        private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            _controller.DeviceAtsign = _controller.NormalizeAtsign(DeviceCombo.Text);
            _controller.ClientAtsign = _controller.NormalizeAtsign(ClientCombo.Text);
            _controller.DeviceName = DeviceName.Text;
            _controller.NextPage();
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
    }
}
