using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using static NoPortsInstaller.ActivateController;

namespace NoPortsInstaller.Pages.Activate
{
    
    /// <summary>
    /// Interaction logic for Approve.xaml
    /// </summary>
    public partial class Approve : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        private string response = "";
       IEnumerable<EnrollmentRecord> enrollments = new List<EnrollmentRecord>();
        public Approve()
        {
            InitializeComponent();
            Header.Content = $"Generate atKeys for {_controller.DeviceAtsign}";
			FillEnrollmentRequests();
        }

        private void ApproveButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender != null && sender is Button)
            {
                Button button = (Button)sender;
                EnrollmentRecord record = (EnrollmentRecord)button.CommandParameter;
                RemoveEnrollment(record.Id);
                try
                {
                    ActivateController.Approve(record.Id);
                }
                catch (Exception ex)
                {
                    _controller.LoadError(ex);
                }
                FillEnrollmentRequests();
            }
        }

        private void DenyButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender != null && sender is Button)
            {
                Button button = (Button)sender;
                EnrollmentRecord record = (EnrollmentRecord)button.CommandParameter;
                RemoveEnrollment(record.Id);
                try
                {
                    ActivateController.Deny(record.Id);
                }
                catch (Exception ex)
                {
                    _controller.LoadError(ex);
                }
                FillEnrollmentRequests();
            }
        }

        private void RefreshButton_Click(object sender, RoutedEventArgs e)
        {
            FillEnrollmentRequests();
        }

        private void RemoveEnrollment(string Id)
		{
			enrollments = enrollments.Where(delegate (EnrollmentRecord enrollmentRecord)
			{
				return enrollmentRecord.Id != Id;
			});
            RedrawEnrollments();
        }

        private void RedrawEnrollments()
        {
			icEnrollments.ItemsSource = enrollments;
			icEnrollments.UpdateLayout();
		}

		private void FillEnrollmentRequests()
        {
			try
			{
				enrollments = ActivateController.ListEnrollments();
            }
            catch (Exception e)
            {
                InstallLogger.Log("Failed to find any active Enrollments");
                InstallLogger.Log(e.Message);
                return;
            }
            enrollments = enrollments.Append(new EnrollmentRecord("fake-id-asdfasdfasdfasdf", "myDevice"));
            RedrawEnrollments();
        }

        private void BackPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.PreviousPage();
        }

		private void Home_Click(object sender, RoutedEventArgs e)
		{
			_controller.LoadPages(InstallType.Home);
        }

		private void NewOtpButton_Click(object sender, RoutedEventArgs e)
		{
            response = ActivateController.GenerateOTP();
            char[] chars = response.ToCharArray();
            if (chars.Length < 6) return;
            OtpBox1.Text = chars[0].ToString();
            OtpBox2.Text = chars[1].ToString();
            OtpBox3.Text = chars[2].ToString();
            OtpBox4.Text = chars[3].ToString();
            OtpBox5.Text = chars[4].ToString();
            OtpBox6.Text = chars[5].ToString();
		}
	}
}
