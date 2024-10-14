import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:at_client/at_client.dart';
import 'package:at_policy/at_policy.dart';

// ignore: implementation_imports
import 'package:alfred/src/type_handlers/websocket_type_handler.dart';
import 'package:noports_core/sshnp_foundation.dart';

admin(
  Alfred app,
  String pathPrefix,
  PolicyAPI api,
  List<String> deviceAtsigns,
  String atDirectory,
) {
  // Track connected clients
  var users = <WebSocket>[];

  var atSignMap = {};

  atSignMap[api.policyAtSign] = {
    'atSign': api.policyAtSign,
    'status': 'Activated',
  };
  for (String das in deviceAtsigns) {
    atSignMap[das] = {
      'atSign': das,
      'status': 'Activated',
    };
  }

  // WebSocket chat relay implementation
  app.get('$pathPrefix/ws', (req, res) {
    final uri = '$pathPrefix/ws';
    return WebSocketSession(
      onOpen: (ws) {
        stderr.writeln('Opening $uri websocket');
        users.add(ws);
      },
      onClose: (ws) {
        stderr.writeln('Closing $uri websocket');
        users.remove(ws);
      },
      onMessage: (ws, dynamic data) async {
        stderr.writeln('Received $data on the $uri websocket');
      },
    );
  });

  app.get('$pathPrefix/info', (req, res) async {
    final rd = [];
    for (String das in deviceAtsigns) {
      rd.add(atSignMap[das]);
    }
    final r = jsonEncode({
      'policyAtsign': atSignMap[api.policyAtSign],
      'deviceAtsigns': rd,
    });
    stderr.writeln('Sent info: $r');
    return r;
  });

  app.get('$pathPrefix/devices', (req, res) async {
    final r = jsonEncode(await api.getDevices());
    stderr.writeln('Sent devices');
    return r;
  });

  String activateCommand;
  String? firstActivateArg;
  if (Platform.executable.endsWith('np_admin')) {
    // Production usage - we're using the compiled binary
    final executableLocation =
    (Platform.resolvedExecutable.split(Platform.pathSeparator)
      ..removeLast())
        .join(Platform.pathSeparator);
    activateCommand = Directory(
        [executableLocation, 'at_activate'].join(Platform.pathSeparator))
        .toString();
  } else {
    // TODO Maybe do something smarter here, but this is for dev purposes only
    activateCommand = 'dart';
    firstActivateArg = 'bin/activate_cli.dart';
  }

  Future<String> generateEnrollPasscode(String deviceAtsign) async {
    return '23ab45cd';
    // List<String> args = [];
    // if (firstActivateArg != null) {
    //   args.add(firstActivateArg);
    // }
    // args.addAll('-a $deviceAtsign -r $atDirectory'.split(' '));
    // final pr = Process.runSync(activateCommand, args);
    // stderr.writeln('generateOtp stderr: ${pr.stderr}');
    // stderr.writeln('generateOtp stdout: ${pr.stdout}');
    // return pr.stdout;
  }

  String generateInstallCommand(String enrollPasscode, DeviceInfo di) {
    return './universal.sh '
        ' --local build/sshnp.zip -t device'
        ' -c ${api.policyAtSign} -p ${api.policyAtSign} -d ${di.deviceAtsign} -n ${di.devicename}'
        ' -dp $enrollPasscode'
        ' --at-directory vip.ve.atsign.zone --device-type headless';
  }

  app.post('$pathPrefix/devices', (req, res) async {
    Map reqBody = await req.body as Map;
    stderr.writeln(reqBody);

    DeviceInfo di = DeviceInfo(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      deviceAtsign: reqBody['deviceAtsign'],
      policyAtsign: reqBody['policyAtsign'],
      managerAtsigns: [reqBody['policyAtsign']],
      devicename: reqBody['devicename'],
      deviceGroupName:
          reqBody['deviceGroupName'] ?? DefaultSshnpdArgs.deviceGroupName,
      version: '0.0.0',
      corePackageVersion: '0.0.0',
      supportedFeatures: {},
      allowedServices: [],
      status: 'Pending',
    );

    try {
      await api.createDevice(di);
      stderr.writeln('Created device ${di.devicename}');

      String otp = await generateEnrollPasscode(di.deviceAtsign);
      return jsonEncode({
        'command': generateInstallCommand(otp, di)
      });
    } catch (e) {
      res.statusCode = 400;
      await res.send(e.toString());
    }
  });

  app.delete('$pathPrefix/devices', (req, res) async {
    await api.deleteDevices();
  });

  api.eventStream.listen((s) {
    for (final u in users) {
      u.send(s);
    }
  });
}

policy(Alfred app, String pathPrefix, PolicyAPI api) {
  // policy log events
  app.get('$pathPrefix/logs', (req, res) async {
    stderr.writeln('Fetching policy log events');
    final now = DateTime.now();
    final r = jsonEncode(await api.getLogEvents(
      from: now.subtract(Duration(hours: 24)).millisecondsSinceEpoch,
      to: now.millisecondsSinceEpoch,
    ));
    stderr.writeln('Fetched policy log events');
    return r;
  });

  // all groups TODO add query parameters for search, pagination etc
  app.get('$pathPrefix/group', (req, res) async {
    stderr.writeln('Fetching all groups');
    final r = jsonEncode(await api.getUserGroups());
    stderr.writeln('Fetched all groups');
    return r;
  });

  // get by group ID
  app.get('$pathPrefix/group/:id', (req, res) async {
    final id = req.params['id'].toString();
    stderr.writeln('Fetching group $id');
    final g = await api.getUserGroup(id);
    if (g == null) {
      res.statusCode = 404;
      await res.send('No group with id $id');
      return jsonEncode({});
    }
    final r = jsonEncode(g);
    stderr.writeln('Fetched group $id (${g.name})');
    return r;
  });

  // create new group
  app.post('$pathPrefix/group', (req, res) async {
    stderr.writeln('Creating new group');
    UserGroup ug;
    try {
      ug = UserGroup.fromJson((await req.body)! as Map<String, dynamic>);
    } catch (_) {
      throw IllegalArgumentException('Unable to construct User from this json');
    }
    try {
      await api.createUserGroup(ug);
      stderr.writeln('Updated group ${ug.name}');
      return jsonEncode(ug);
    } catch (e) {
      res.statusCode = 400;
      await res.send(e.toString());
    }
  });

  // update group
  app.put('$pathPrefix/group/:id', (req, res) async {
    final id = req.params['id'].toString();
    stderr.writeln('Updating group with ID $id');

    UserGroup ug;
    try {
      ug = UserGroup.fromJson((await req.body)! as Map<String, dynamic>);
    } catch (_) {
      throw IllegalArgumentException('Unable to construct User from this json');
    }
    if (ug.id != id) {
      throw IllegalArgumentException('GroupID mis-match');
    }
    try {
      await api.updateUserGroup(ug);
      stderr.writeln('Updated group ${ug.name}');
      return jsonEncode(ug);
    } catch (e) {
      res.statusCode = 400;
      await res.send(e.toString());
    }
  });

  // delete group
  app.delete('$pathPrefix/group/:id', (req, res) async {
    final id = req.params['id'].toString();
    stderr.writeln('Updating group with ID $id');
    try {
      await api.deleteUserGroup(id);
    } catch (e) {
      res.statusCode = 400;
      await res.send(e.toString());
    }
  });

  // Track connected clients
  var users = <WebSocket>[];

  // WebSocket chat relay implementation
  app.get('$pathPrefix/ws', (req, res) {
    final uri = '$pathPrefix/ws';
    return WebSocketSession(
      onOpen: (ws) {
        stderr.writeln('Opening $uri websocket');
        users.add(ws);
      },
      onClose: (ws) {
        stderr.writeln('Closing $uri websocket');
        users.remove(ws);
      },
      onMessage: (ws, dynamic data) async {
        stderr.writeln('Received $data on the $uri websocket');
      },
    );
  });

  final events = [];
  api.eventStream.listen((s) {
    events.insert(0, jsonDecode(s));
    for (final u in users) {
      u.send(s);
    }
  });

  app.get('$pathPrefix/events', (req, res) {
    return jsonEncode(events);
  });
}
