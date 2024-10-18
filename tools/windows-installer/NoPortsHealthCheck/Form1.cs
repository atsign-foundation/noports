using Microsoft.Win32;
using System;
using System.Windows.Forms;

namespace NoPortsHealthCheck
{
    public partial class Form1 : Form
    {
        static readonly string userHome = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        static readonly string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        readonly bool isUserAdmin = Program.IsUserAdmin();
        readonly bool canWriteUserHome = Program.CanWriteToDirectory(userHome);
        readonly bool canWriteLocalAppData = Program.CanWriteToDirectory(localAppData);
        readonly bool canWriteNetworkService = Program.CanWriteToDirectory(Environment.ExpandEnvironmentVariables("%systemroot%")
              + @"\ServiceProfiles\LocalService\");
        readonly bool canWriteRegistry = Program.CanWriteToRegistry(Registry.LocalMachine, "SOFTWARE\\TestKey");
        readonly bool canModifyPath = Program.CanModifyEnvironmentVariable();
        readonly bool canCreateServices = Program.CanCreateServices();
        public Form1()
        {
            InitializeComponent();
            this.Text = "NoPorts Health Check";
            checkBox1.Checked = isUserAdmin;
            if (isUserAdmin)
            {
                Program.Log("User is Admin");
            }
            else
            {
                Program.Log("User is not Admin, try running as admin.");
            }
            checkBox2.Checked = canWriteUserHome;
            checkBox3.Checked = canWriteLocalAppData;
            checkBox4.Checked = canWriteNetworkService;
            checkBox5.Checked = canWriteRegistry;
            checkBox6.Checked = canModifyPath;
            checkBox7.Checked = canCreateServices;
            if (isUserAdmin && canWriteUserHome && canWriteLocalAppData && canWriteNetworkService && canWriteRegistry && canModifyPath && canCreateServices)
            {
                Program.ShowSuccessLogs();
            }
            if (!isUserAdmin)
            {
                Program.ShowErrorLogs();
            }
        }

        private void label8_Click(object sender, EventArgs e)
        {

        }

        private void checkBox7_CheckedChanged(object sender, EventArgs e)
        {

        }
    }
}
