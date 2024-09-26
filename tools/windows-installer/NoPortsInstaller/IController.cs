using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller
{
    public interface IController
    {
        string InstallDirectory { get; set; }
        InstallType InstallType { get; set; }
        string ClientAtsign { get; set; }
        string DeviceAtsign { get; set; }
        string DeviceName { get; set; }
        string RegionAtsign { get; set; }
        public string AdditionalArgs { get; set; }
        bool IsInstalled { get; set; }
        List<Page> Pages { get; set; }
        Window? Window { get; set; }
        public string AtsignKeysDirectory { get; }

        Task Install(ProgressBar progress, Label status);
        Task Uninstall(ProgressBar progress);
        Task Onboard();
        Task Approve();
        void Enroll();
        void LoadPages(InstallType type);
        void NextPage();
        void PreviousPage();
        void UpdateConfigRegistry();
        void PopulateAtsigns(ComboBox box);
        string NormalizeAtsign(string atsign);
        string NormalizeArgs(string args);
        string CheckAtsignStatus(string atsign);
    }
}
