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
}

