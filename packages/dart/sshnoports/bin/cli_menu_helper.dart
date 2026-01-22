import 'dart:io';
import 'package:cli_menu/cli_menu.dart';
import 'package:chalkdart/chalk.dart';
import 'package:noports_core/admin_v2.dart';

class CliMenuHelper {
  static Future<String?> selectClientId(List<Client> clients) async {
    if (clients.isEmpty) {
      print(chalk.red('No clients available.'));
      return null;
    }

    final List<String> menuItems = [];
    for (int i = 0; i < clients.length; i++) {
      final Client client = clients[i];
      menuItems.add('${chalk.cyan(client.id ?? 'N/A')} - ${chalk.yellow(client.name)} (${client.atSign})');
    }
    menuItems.add(chalk.green('→ Enter custom ID'));
    menuItems.add(chalk.red('✗ Cancel'));

    print(chalk.bold.white('\nSelect a Client (use arrow keys):'));
    final menu = Menu(menuItems);
    final result = menu.choose();

    if (result.index == clients.length + 1) {
      return null;
    } else if (result.index == clients.length) {
      stdout.write(chalk.white('Enter custom client ID: '));
      return stdin.readLineSync();
    } else {
      return clients[result.index].id;
    }
  }

  static Future<String?> selectClientGroupId(List<ClientGroup> clientGroups) async {
    if (clientGroups.isEmpty) {
      print(chalk.red('No client groups available.'));
      return null;
    }

    final List<String> menuItems = [];
    for (int i = 0; i < clientGroups.length; i++) {
      final ClientGroup clientGroup = clientGroups[i];
      menuItems.add('${chalk.cyan(clientGroup.id ?? 'N/A')} - ${chalk.yellow(clientGroup.name)}');
    }
    menuItems.add(chalk.green('→ Enter custom ID'));
    menuItems.add(chalk.red('✗ Cancel'));

    print(chalk.bold.white('\nSelect a Client Group (use arrow keys):'));
    final menu = Menu(menuItems);
    final result = menu.choose();

    if (result.index == clientGroups.length + 1) {
      return null;
    } else if (result.index == clientGroups.length) {
      stdout.write(chalk.white('Enter custom client group ID: '));
      return stdin.readLineSync();
    } else {
      return clientGroups[result.index].id;
    }
  }

  static Future<String?> selectDaemonId(List<Daemon> daemons) async {
    if (daemons.isEmpty) {
      print(chalk.red('No daemons available.'));
      return null;
    }

    final List<String> menuItems = [];
    for (int i = 0; i < daemons.length; i++) {
      final Daemon daemon = daemons[i];
      menuItems.add('${chalk.cyan(daemon.id ?? 'N/A')} - ${chalk.yellow(daemon.atSign)}');
    }
    menuItems.add(chalk.green('→ Enter custom ID'));
    menuItems.add(chalk.red('✗ Cancel'));

    print(chalk.bold.white('\nSelect a Daemon (use arrow keys):'));
    final menu = Menu(menuItems);
    final result = menu.choose();

    if (result.index == daemons.length + 1) {
      return null;
    } else if (result.index == daemons.length) {
      stdout.write(chalk.white('Enter custom daemon ID: '));
      return stdin.readLineSync();
    } else {
      return daemons[result.index].id;
    }
  }

  static Future<String?> selectServiceId(List<Service> services) async {
    if (services.isEmpty) {
      print(chalk.red('No services available.'));
      return null;
    }

    final List<String> menuItems = [];
    for (int i = 0; i < services.length; i++) {
      final Service service = services[i];
      menuItems.add('${chalk.cyan(service.id ?? 'N/A')} - ${chalk.yellow(service.deviceName)} (daemon: ${service.daemonId})');
    }
    menuItems.add(chalk.green('→ Enter custom ID'));
    menuItems.add(chalk.red('✗ Cancel'));

    print(chalk.bold.white('\nSelect a Service (use arrow keys):'));
    final menu = Menu(menuItems);
    final result = menu.choose();

    if (result.index == services.length + 1) {
      return null;
    } else if (result.index == services.length) {
      stdout.write(chalk.white('Enter custom service ID: '));
      return stdin.readLineSync();
    } else {
      return services[result.index].id;
    }
  }

  static bool confirm(String message) {
    final menu = Menu([
      chalk.green('✓ Yes'),
      chalk.red('✗ No'),
    ]);
    print(chalk.bold.white('\n$message'));
    final result = menu.choose();
    return result.index == 0;
  }
}
