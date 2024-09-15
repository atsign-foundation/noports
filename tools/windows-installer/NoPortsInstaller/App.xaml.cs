using NoPortsInstaller.Pages;
using System.Windows;

namespace NoPortsInstaller;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    public static IController ControllerInstance { get; set; }
    public App()
    {
        ControllerInstance = new Controller();
    }

    public void OnStartup(object sender, StartupEventArgs e)
    {
        MainWindow mainWindow = new();
        mainWindow.Show();
        if (e.Args.Length == 1 && e.Args[0] == "u")
        {
            ControllerInstance.InstallType = InstallType.Uninstall;
            ControllerInstance.LoadPages();
        }
    }
}

