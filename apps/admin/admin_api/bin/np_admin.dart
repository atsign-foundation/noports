import 'dart:io';

import 'package:admin_api/src/expose_apis.dart' as expose;
import 'package:alfred/alfred.dart';
import 'package:alfred/src/type_handlers/websocket_type_handler.dart';
import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:noports_core/admin.dart';
import 'package:noports_core/utils.dart';
import 'package:noports_core/version.dart' as core;

const String _description =
    'NoPorts admin: serves the NoPorts policy administration web app'
    ' and its REST API.';

void main(List<String> args) async {
  final ArgParser parser = CLIBase.createArgsParser(
    namespace: 'sshnp',
    hide: CLIBase.hideableArgs,
  );

  final String bindIpArgName = 'bind-ip';
  parser.addOption(bindIpArgName,
      abbr: 'b',
      help: 'Bind to something other than the default',
      mandatory: false,
      defaultsTo: '127.0.0.1');
  final String bindPortArgName = 'bind-port';
  parser.addOption(bindPortArgName,
      abbr: 'p',
      help: 'Bind to something other than the default port',
      mandatory: false,
      defaultsTo: '3000');

  parser.addFlag('version', negatable: false, help: 'Print version');

  final ArgResults parsedArgs;
  final String bindIp;
  final int bindPort;
  try {
    parsedArgs = parser.parse(args);

    if (parsedArgs['help'] == true) {
      stdout.write(
          formatCliHelp(description: _description, optionsUsage: parser.usage));
      exit(0);
    }

    if (parsedArgs['version'] == true) {
      // np_admin is versioned by noports_core, as it has no
      // release version of its own
      stdout.writeln('$binaryName ${core.packageVersion}');
      exit(0);
    }

    bindIp = parsedArgs[bindIpArgName];
    bindPort = int.parse(parsedArgs[bindPortArgName]);
  } on ArgumentError catch (e) {
    stderr.write(
        formatCliHelp(description: _description, optionsUsage: parser.usage));
    stderr.writeln(e.message);
    exit(1);
  } on FormatException catch (e) {
    stderr.write(
        formatCliHelp(description: _description, optionsUsage: parser.usage));
    stderr.writeln(e.message);
    exit(1);
  } catch (err) {
    stderr.write(
        formatCliHelp(description: _description, optionsUsage: parser.usage));
    stderr.writeln(err);
    exit(1);
  }

  // Before going on to create our AtClient, let's do a sanity-check on the
  // "bind-ip" and "bind-port" parameters
  try {
    HttpServer sanityCheck = await HttpServer.bind(bindIp, bindPort);
    await sanityCheck.close(force: true);
  } catch (err) {
    stderr.writeln(err);
    exit(1);
  }

  final CLIBase cli;
  try {
    cli = await CLIBase.fromCommandLineArgs(args, parser: parser);
  } on ArgumentError catch (e) {
    stderr.write(
        formatCliHelp(description: _description, optionsUsage: parser.usage));
    stderr.writeln(e.message);
    exit(1);
  } on FormatException catch (e) {
    stderr.write(
        formatCliHelp(description: _description, optionsUsage: parser.usage));
    stderr.writeln(e.message);
    exit(1);
  } catch (err) {
    stderr.write(
        formatCliHelp(description: _description, optionsUsage: parser.usage));
    stderr.writeln(err);
    stderr.writeln(err.runtimeType);
    exit(1);
  }

  stderr.writeln('Will bind to port $bindPort on $bindIp');

  final api = PolicyService.withAtClient(atClient: cli.atClient);
  await api.init();

  final app = Alfred();
  app.all('*', cors(origin: 'http://localhost:5173'));
  if (Platform.executable.endsWith('np_admin') ||
      Platform.executable.endsWith('np_admin.exe')) {
    // Production usage - we're using the compiled binary
    final executableLocation =
        (Platform.resolvedExecutable.split(Platform.pathSeparator)
              ..removeLast())
            .join(Platform.pathSeparator);
    final dir = Directory(
        [executableLocation, 'web', 'admin'].join(Platform.pathSeparator));
    print('Will serve webapp from $dir');
    app.get('/*', (req, res) => dir);
  } else {
    // TODO Maybe do something smarter here, but this is for dev purposes only
    final dir = Directory('../../../apps/admin/webapp/dist'
        .replaceAll('/', Platform.pathSeparator));
    print('Will serve webapp from ${dir.absolute}');
    app.get('/*', (req, res) => dir);
  }
  expose.policy(app, '/api/policy', api);

  // Track connected clients
  var users = <WebSocket>[];

  // WebSocket chat relay implementation
  app.get('/api/policy/events', (req, res) {
    return WebSocketSession(
      onOpen: (ws) {
        users.add(ws);
      },
      onClose: (ws) {
        users.remove(ws);
      },
      onMessage: (ws, dynamic data) async {
        stderr.writeln('Received $data on the events websocket');
      },
    );
  });

  api.eventStream.listen((s) {
    for (final u in users) {
      u.send(s);
    }
  });

  await app.listen(bindPort, bindIp);
}
