﻿using System.Windows.Controls;

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
             DoInstall();
        }

        private async void DoInstall()
        {
			await _controller.Install(InstallProgress, Status);
            NextPageButton.IsEnabled = true;
        }

		private void BackPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
		{
            _controller.Pages.Clear();
            _controller.Pages.Add(new Setup());
            _controller.NextPage();
		}

		private void NextPageButton_Click(object sender, System.Windows.RoutedEventArgs e)
		{
            _controller.NextPage();
		}
	}
}
