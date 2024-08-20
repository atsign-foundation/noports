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
        string MultipleDevices { get; set; }
        bool IsInstalled { get; set; }
        List<Page> Pages { get; set; }
        Window? Window { get; set; }

        void Install(ProgressBar progress, Label status);
        void Uninstall(ProgressBar progress);
        void LoadPages();
        void NextPage();
        void PreviousPage();
        void UpdateConfigRegistry();
        void PopulateAtsigns(ComboBox box);
        string NormalizeAtsign(string atsign);
    }
}
