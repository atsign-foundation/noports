using NoPortsInstaller.Pages;
using System.Windows;

namespace NoPortsInstaller;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    public static InstallController ControllerInstance { get; set; }
    public App()
    {
        ControllerInstance = new InstallController();
    }

    public void OnStartup(object sender, StartupEventArgs e)
    {
        if (e.Args.Length == 1 && e.Args[0] == "u")
        {
            UninstallWindow uninstallWindow = new UninstallWindow();
            uninstallWindow.Show();
        }
        else
        {
            MainWindow mainWindow = new MainWindow();
            mainWindow.Show();
        }
    }
}

