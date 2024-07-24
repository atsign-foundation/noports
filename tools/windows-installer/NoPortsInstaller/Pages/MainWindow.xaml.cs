using System.Windows;

namespace NoPortsInstaller;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{
    private Installer _installer;
    public MainWindow()
    {
        InitializeComponent();
        _installer = App.Instance;
        _installer.Setup(this);
    }
}