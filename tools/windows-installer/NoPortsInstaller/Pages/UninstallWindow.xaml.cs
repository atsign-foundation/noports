using System.Windows;

namespace NoPortsInstaller.Pages;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class UninstallWindow : Window
{
    private Installer _installer;
    public UninstallWindow()
    {
        InitializeComponent();
        _installer = App.Instance;
    }

    private void NextPageButton_Click(object sender, RoutedEventArgs e)
    {
        this.Content = new Uninstall(_installer);
    }

}