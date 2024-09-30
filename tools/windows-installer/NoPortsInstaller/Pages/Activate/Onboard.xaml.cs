using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Activate
{
    /// <summary>
    /// Interaction logic for Onboard.xaml
    /// </summary>
    public partial class Onboard : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        private readonly Process at_activate = new();
        public Onboard()
        {
            InitializeComponent();
            at_activate.StartInfo.FileName = Path.Combine(_controller.InstallDirectory, "at_activate.exe");
            at_activate.StartInfo.Arguments = $"onboard -a ";
            at_activate.StartInfo.UseShellExecute = false;
            at_activate.StartInfo.RedirectStandardOutput = true;
            at_activate.StartInfo.RedirectStandardInput = true;
            at_activate.StartInfo.RedirectStandardError = true;
            at_activate.StartInfo.CreateNoWindow = true;
        }

        private void BackPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.PreviousPage();
            _controller.LoadPages(InstallType.Home);
        }
        // Event handler for TextChanged
        private void OtpBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (sender is TextBox textBox)
            {
                if (textBox.Text.Length == 1)
                {
                    // Move focus to the next TextBox
                    switch (textBox.Name)
                    {
                        case "OtpBox1":
                            OtpBox2.Focus();
                            break;
                        case "OtpBox2":
                            OtpBox3.Focus();
                            break;
                        case "OtpBox3":
                            OtpBox4.Focus();
                            break;
                    }
                }

                // Handle backspace (if the user tries to clear a box)
                if (textBox.Text.Length == 0)
                {
                    switch (textBox.Name)
                    {
                        case "OtpBox4":
                            OtpBox3.Focus();
                            break;
                        case "OtpBox3":
                            OtpBox2.Focus();
                            break;
                        case "OtpBox2":
                            OtpBox1.Focus();
                            break;
                    }
                }

                if (OtpBox1.Text.Length == 1 && OtpBox2.Text.Length == 1 && OtpBox3.Text.Length == 1 && OtpBox4.Text.Length == 1)
                {
                    Generate.IsEnabled = true;
                }
                else
                {
                    Generate.IsEnabled = false;
                }
            }

        }

        private void Start_AtActivate(string atsign)
        {
            at_activate.StartInfo.Arguments = $"onboard -a {atsign}";
            at_activate.Start();
            while (!at_activate.HasExited && !IsProcessReady(at_activate))
            {
                Thread.Sleep(100); // Sleep for a short interval before checking again
            }

            if (at_activate.HasExited)
            {
                throw new IOException("Failed to start at_activate process.");
            }
            else
            {
                OtpInput.Visibility = Visibility.Visible;
                Console.WriteLine("");
            }
        }

        private static bool IsProcessReady(Process process)
        {
            // Check if the process has started and is ready to receive input
            return process.StandardInput.BaseStream.CanWrite;
        }

        private void Submit_Click(object sender, RoutedEventArgs e)
        {
            ActivateResponseText.Visibility = Visibility.Hidden;
            ActivateResponseText.Content = "";
            _controller.DeviceAtsign = _controller.NormalizeAtsign(Atsign.Text);
            var response = ActivateController.Status(_controller.DeviceAtsign);
            if (response == AtsignStatus.NotActivated)
            {
                ActivateResponseText.Content = "Check the email that was used to create the atsign \n \n Enter One Time Password (OTP):";
                ActivateResponseText.Visibility = Visibility.Visible;

                Start_AtActivate(_controller.DeviceAtsign);
                Submit.IsEnabled = false;
            }
            else if (response == AtsignStatus.Activated)
            {
                ActivateResponseText.Content = "This atsign is already activated, please continue to device/client installation";
                ActivateResponseText.Visibility = Visibility.Visible;
            }
            else
            {
                ActivateResponseText.Content = "This atsign does not exist.";
                ActivateResponseText.Visibility = Visibility.Visible;
            }
        }

        private void Generate_Click(object sender, RoutedEventArgs e)
        {
            string otp = $"{OtpBox1.Text}{OtpBox2.Text}{OtpBox3.Text}{OtpBox4.Text}".ToUpper();
            if (!at_activate.HasExited)
            {
                at_activate.StandardInput.WriteLine(otp);
                at_activate.WaitForExit();
                if (at_activate.ExitCode == 0)
                {
                    _controller.NextPage();
                }
                else
                {
                    ActivateResponseText.Content = "Invalid OTP, please try again.";
                    at_activate.Kill();
                    at_activate.Start();
                }
            }
        }
    }
}
