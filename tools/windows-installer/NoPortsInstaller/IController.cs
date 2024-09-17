﻿using System.Windows;
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
        string PermittedPorts { get; set; }
        string MultipleDevices { get; set; }
        string MultipleManagers { get; set; }
        bool IsInstalled { get; set; }
        string AtkeysPath { get; set; }
        List<Page> Pages { get; set; }
        Window? Window { get; set; }

        Task Install(ProgressBar progress, Label status);
        Task Uninstall(ProgressBar progress);
        void LoadPages();
        void NextPage();
        void PreviousPage();
        void UpdateConfigRegistry();
        void PopulateAtsigns(ComboBox box);
        void MoveUploadedAtkeys();
        string NormalizeAtsign(string atsign);
        string NormalizeMultipleManagers(string atsigns);
        string NormalizePermittedPorts(string ports);
    }
}