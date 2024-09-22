using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Activate
{
    /// <summary>
    /// Interaction logic for Approve.xaml
    /// </summary>
    public partial class Approve : Page
    {
        private readonly IController _controller = App.ControllerInstance;
        private readonly Process at_activate = new();
        private string response { get; set; }
        private string id { get; set; }
        public Approve()
        {
            at_activate.StartInfo.FileName = Path.Combine(_controller.InstallDirectory, "at_activate.exe");
            at_activate.StartInfo.Arguments = $"otp -a {_controller.DeviceAtsign}";
            at_activate.StartInfo.UseShellExecute = false;
            at_activate.StartInfo.RedirectStandardOutput = true;
            at_activate.StartInfo.RedirectStandardInput = true;
            at_activate.StartInfo.RedirectStandardError = true;
            at_activate.StartInfo.CreateNoWindow = true;
            at_activate.Start();
            response = at_activate.StandardOutput.ReadToEnd();
            at_activate.WaitForExit();
            InitializeComponent();
            Header.Content = $"Generate atKeys for {_controller.DeviceAtsign}";
            FillEnrollmentRequest();
            id = "";
        }

        private void ApproveButton_Click(object sender, RoutedEventArgs e)
        {
            at_activate.StartInfo.Arguments = $"approve -a {_controller.DeviceAtsign} -i {id}";
            at_activate.Start();
            at_activate.WaitForExit();
            FillEnrollmentRequest();
        }

        private void DenyButton_Click(object sender, RoutedEventArgs e)
        {
            at_activate.StartInfo.Arguments = $"deny -a {_controller.DeviceAtsign} -i {id}";
            at_activate.Start();
            at_activate.WaitForExit();
            FillEnrollmentRequest();
        }

        private void RefreshButton_Click(object sender, RoutedEventArgs e)
        {
            FillEnrollmentRequest();
        }

        private void FillEnrollmentRequest()
        {
            id = _controller.GetPendingRequests();
            if (!string.IsNullOrEmpty(id))
            {
                DeviceNameLabel.Content = _controller.DeviceName;
                IdLabel.Content = id;
                Enrollment.Visibility = Visibility.Visible;
            }
            else
            {
                Enrollment.Visibility = Visibility.Hidden;
            }
        }

        private void BackPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.PreviousPage();
        }

        private void FillOtp(object sender, EventArgs e)
        {
            char[] chars = response.ToCharArray();
            if (sender is TextBox textBox)
            {
                switch (textBox.Name)
                {
                    case "OtpBox1":
                        textBox.Text = chars[0].ToString();
                        break;
                    case "OtpBox2":
                        textBox.Text = chars[1].ToString();
                        break;
                    case "OtpBox3":
                        textBox.Text = chars[2].ToString();
                        break;
                    case "OtpBox4":
                        textBox.Text = chars[3].ToString();
                        break;
                    case "OtpBox5":
                        textBox.Text = chars[4].ToString();
                        break;
                    case "OtpBox6":
                        textBox.Text = chars[5].ToString();
                        break;
                }
            }
        }

        private void Home_Click(object sender, RoutedEventArgs e)
        {
            _controller.LoadPages(InstallType.Home);
        }
    }
}
