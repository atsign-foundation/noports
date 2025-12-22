import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:args/args.dart';

void main(List<String> args) async {
  final ArgParser parser = ArgParser();
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
      defaultsTo: '3100');

  final ArgResults parsedArgs;
  final String bindIp;
  final int bindPort;
  try {
    parsedArgs = parser.parse(args);
    bindIp = parsedArgs[bindIpArgName];
    bindPort = int.parse(parsedArgs[bindPortArgName]);
  } on ArgumentError catch (e) {
    stderr.writeln('Usage: \n${parser.usage}\n');
    stderr.writeln(e.message);
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln('Usage: \n${parser.usage}\n');
    stderr.writeln(e.message);
    exit(1);
  } catch (err) {
    stderr.writeln('Usage: \n${parser.usage}\n');
    stderr.writeln(err);
    exit(1);
  }

  stderr.writeln('Will bind to port $bindPort on $bindIp');

  final app = Alfred();

  //   app.all('/typed-example/:id:int/:name', (req, res) {
  //     req.params['id'] != null;
  //     req.params['id'] is int;
  //     req.params['name'] != null;
  //   });
  app.post('/api/ph/et/:atsign64', (req, res) async {
    String atSign64 = req.params['atsign64'];
    String atSign = atSign64;
    try {
      atSign = String.fromCharCodes(base64Decode(atSign64));
    } catch (_) {
      res.statusCode = 404;
      return;
    }
    stdout.writeln(
        '${DateTime.now().toUtc().toIso8601String()} | $atSign | ${await req.body}\n');

    res.statusCode = 200;
  });

  await app.listen(bindPort, bindIp);
}
