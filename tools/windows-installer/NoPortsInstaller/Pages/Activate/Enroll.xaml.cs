using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Animation;

namespace NoPortsInstaller.Pages.Activate
{
    /// <summary>
    /// Interaction logic for Enroll.xaml
    /// </summary>
    public partial class Enroll : Page
    {
        private readonly Controller _controller = App.ControllerInstance;
        public Enroll()
        {
            InitializeComponent();
            StartLoadingAnimation();
            Header.Content = $"Generate atKeys for {_controller.DeviceAtsign}";
            OTPLabel.Content = $"at_activate otp -a \"{_controller.DeviceAtsign}\"";
            ApproveLabel.Content = $"at_activate approve -a \"{_controller.DeviceAtsign}\" -i [enrollmentId]";

        }

        // Event handler for TextChanged
        private void OtpBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (sender is TextBox textBox)
            {
                if (textBox.Text.Length == 1)
                {
                    // Move focus to the next TextBox.
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
                        case "OtpBox4":
                            OtpBox5.Focus();
                            break;
                        case "OtpBox5":
                            OtpBox6.Focus();
                            break;
                        case "OtpBox6":
                            break;
                    }
                }

                // Handle backspace (if the user tries to clear a box)
                if (textBox.Text.Length == 0)
                {
                    switch (textBox.Name)
                    {
                        case "OtpBox6":
                            OtpBox5.Focus();
                            break;
                        case "OtpBox5":
                            OtpBox4.Focus();
                            break;
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

                bool isOtpComplete = OtpBox1.Text.Length == 1 &&
                                     OtpBox2.Text.Length == 1 &&
                                     OtpBox3.Text.Length == 1 &&
                                     OtpBox4.Text.Length == 1 &&
                                     OtpBox5.Text.Length == 1 &&
                                     OtpBox6.Text.Length == 1;

                if (isOtpComplete)
                {
                    Generate.IsEnabled = true;
                }
                else
                {
                    Generate.IsEnabled = false;
                }
            }

        }

        private void BackPageButton_Click(object sender, RoutedEventArgs e)
        {
            _controller.PreviousPage();
        }

        private async void Generate_Click(object sender, RoutedEventArgs e)
        {
            EnrollResponse.Content = "";
            string otp = $"{OtpBox1.Text}{OtpBox2.Text}{OtpBox3.Text}{OtpBox4.Text}{OtpBox5.Text}{OtpBox6.Text}".ToUpper();

            Loading.Visibility = Visibility.Visible;
            try
            {
                bool value = await Task.Run(() => ActivateController.Enroll(otp));
                if (value)
                {
                    _controller.NextPage();
                }
                else
                {
                    EnrollResponse.Content = "Invalid OTP, Enrollment failed. Please make sure you have a valid otp and try again.";
                }
            }
            catch (Exception ex)
            {
                _controller.LoadError(ex);
            }

        }

        private void StartLoadingAnimation()
        {
            // Create a DoubleAnimation for rotation
            // Create a smooth DoubleAnimation for rotation
            DoubleAnimation rotationAnimation = new()
            {
                From = 0,
                To = 360,
                Duration = new Duration(TimeSpan.FromSeconds(1)),
                RepeatBehavior = RepeatBehavior.Forever,
                EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut }
            };

            // Apply the animation to the RotateTransform
            LoadingCircleTransform.BeginAnimation(System.Windows.Media.RotateTransform.AngleProperty, rotationAnimation);
        }
    }

}

