using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{
    private InstallController _controller;
    public MainWindow()
    {
        InitializeComponent();
        _controller = App.ControllerInstance;
        List<Page> pages = new List<Page> { new Setup(_controller), new ConfigureInstall(_controller) };
        _controller.Setup(this, pages);
    }
}