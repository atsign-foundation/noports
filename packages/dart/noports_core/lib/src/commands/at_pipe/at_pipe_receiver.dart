import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:noports_core/version.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'at_pipe.dart';

class AtPipeReceiver extends AtPipe {
  AtPipeReceiver(super.params);

  @override
  Future<int> wrappedMain() async {
    await super.connectAtClient();
    return await run();
  }

  late final ServerSocket serverSocket;

  bool isRunning = true;

  int lastConnectionId = 0;

  Future<int> run() async {
    serverSocket = await ServerSocket.bind('localhost', 0);

    serverSocket.listen(
      (Socket s) => newSocket(s),
      onError: (err) {
        logger.info('serverSocket error $err');
      },
      onDone: () {
        logger.info('serverSocket done');
      },
    );

    SshnpdImpl sshnpd = SshnpdImpl(
      atClient: atClient,
      username: 'atpipe',
      homeDirectory: getHomeDirectory()!,
      device: 'atpipe_${params.pipeName}',
      managerAtsigns: [params.atSign],
      sshClient: SupportedSshClient.openssh,
      ephemeralPermissions: '',
      sshAlgorithm: SupportedSshAlgorithm.ed25519,
      deviceGroup: 'default',
      version: packageVersion,
      permitOpen: ['localhost:${serverSocket.port}'],
      inline: true,
      strict: false,
      notifPreProcessor: preProcess,
    );

    await sshnpd.init();

    await sshnpd.run();

    logger.info('Started successfully');

    while (isRunning) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    return 0;
  }

  void newSocket(Socket s) async {
    int bytesReceived = 0;
    int thisConnectionId = ++lastConnectionId;
    logger.info('Connection $thisConnectionId : listening');
    s.listen(
      (Uint8List data) {
        stdout.add(data);
        bytesReceived += data.length;
        String controlMsg = 'br:$bytesReceived';
        logger.finer(controlMsg);
        s.writeln(controlMsg);
      },
      onError: (err) {
        logger.warning('Error: $err');
        s.destroy();
      },
      onDone: () {
        logger.finer('Connection $thisConnectionId : listen.onDone');
        s.destroy();
      },
    );
    try {
      await s.done;
    } catch (_) {}
    logger.info('Connection $thisConnectionId : done; $bytesReceived bytes');
  }

  Future<void> preProcess(AtNotification notification) async {
    String request = notification.key
        .replaceAll('${notification.to}:', '')
        .split('.')
        .first
        .toLowerCase();

    if (request != 'npt_request') {
      return;
    }

    late final Map envelope = jsonDecode(notification.value!);
    assertValidMapValue(envelope, 'signature', String);
    assertValidMapValue(envelope, 'hashingAlgo', String);
    assertValidMapValue(envelope, 'signingAlgo', String);

    Map<String, dynamic> params = envelope['payload'];

    NptSessionRequest.fromJson(params);

    params['requestedHost'] = 'localhost';
    params['requestedPort'] = serverSocket.port;

    envelope['payload'] = params;
    notification.value = jsonEncode(envelope);
  }
}
