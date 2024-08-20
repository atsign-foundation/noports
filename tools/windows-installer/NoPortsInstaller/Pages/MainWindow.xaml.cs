using System.Windows;

namespace NoPortsInstaller.Pages;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{
    private readonly Controller _controller;
    public MainWindow()
    {
        InitializeComponent();
        _controller = App.ControllerInstance;
        _controller.Window = this;
        _controller.LoadPages();
    }
}