using System.Windows;
using System.Windows.Controls;

namespace NoPortsInstaller.Pages;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class UninstallWindow : Window
{
    private InstallController _controller;
    public UninstallWindow()
    {
        InitializeComponent();
        _controller = App.ControllerInstance;
        var pages = new List<Page> { new Uninstall(_controller), new FinishUninstall(_controller) };
        _controller.Setup(this, pages);
    }

    private void NextPageButton_Click(object sender, RoutedEventArgs e)
    {
        _controller.NextPage();
    }

}