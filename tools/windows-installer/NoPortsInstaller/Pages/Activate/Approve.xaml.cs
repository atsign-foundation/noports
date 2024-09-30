using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages.Activate
{
    /// <summary>
    /// Interaction logic for Approve.xaml
    /// </summary>
    public partial class Approve : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        private string response { get; set; }
        private static EnrollmentRecord? enrollmentRecord;
        public Approve()
        {
            response = ActivateController.GenerateOTP();
            InitializeComponent();
            Header.Content = $"Generate atKeys for {_controller.DeviceAtsign}";
            FillEnrollmentRequest();
        }

        private void ApproveButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                ActivateController.Approve(enrollmentRecord!.Id);
            }
            catch (Exception ex)
            {
                _controller.LoadError(ex);
            }
            FillEnrollmentRequest();
        }

        private void DenyButton_Click(object sender, RoutedEventArgs e)
        {

            FillEnrollmentRequest();
        }

        private void RefreshButton_Click(object sender, RoutedEventArgs e)
        {
            FillEnrollmentRequest();
        }

        private void FillEnrollmentRequest()
        {
            List<EnrollmentRecord> requests = [];
            try
            {
                requests = ActivateController.ListEnrollments();
            }
            catch
            {
                InstallLogger.Log("Failed to find any active enrollments");
                return;
            }
            enrollmentRecord = requests.FirstOrDefault();
            if (enrollmentRecord != null)
            {
                DeviceNameLabel.Content = enrollmentRecord.DeviceName;
                IdLabel.Content = enrollmentRecord.Id;
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
