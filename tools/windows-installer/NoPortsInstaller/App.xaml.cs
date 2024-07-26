using System.Windows;

namespace NoPortsInstaller;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    public static Installer Instance { get; set; }
    public App()
    {
        Instance = new Installer();
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

