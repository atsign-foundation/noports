import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_commons/at_commons.dart';
import 'package:mutex/mutex.dart';
import 'package:noports_core/npt.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'at_pipe.dart';

class AtPipeSender extends AtPipe {
  AtPipeSender(super.params);

  @override
  Future<int> wrappedMain() async {
    await super.connectAtClient();
    return await run();
  }

  Future<int> run() async {
    Npt npt = Npt.create(
      params: NptParams(
        clientAtSign: params.atSign,
        sshnpdAtSign: params.toAtSign ?? params.atSign,
        srvdAtSign: params.relayAtSign,
        localHost: 'localhost',
        remoteHost: 'localhost',
        remotePort: 99999,
        // not important
        device: 'atpipe_${params.pipeName}',
        only443: true,
        relayAuthMode: RelayAuthMode.escr,
        inline: true,
        timeout: Duration(seconds: 30),
        verbose: true,
      ),
      atClient: atClient,
    );

    int localPort = await npt.run();

    Socket socket = await Socket.connect('localhost', localPort);

    int received = -1;
    ByteBuffer rcvBuffer = ByteBuffer();
    Mutex rcvMutex = Mutex();
    const newLineCodeUnit = 10;
    socket.listen(
      (Uint8List data) async {
        await rcvMutex.acquire();
        try {
          for (int element = 0; element < data.length; element++) {
            // If it's a '\n' then complete data has been received, so process it
            if (data[element] == newLineCodeUnit) {
              String controlMsg = '';
              try {
                controlMsg = utf8.decode(rcvBuffer.getData().toList()).trim();
                try {
                  if (controlMsg.isEmpty) {
                    logger.warning(
                      'Empty control message (Uint8List) received',
                    );
                    return;
                  }
                  logger.finer('Received control message: $controlMsg');
                  List<String> split = controlMsg.split(':');
                  switch (split[0]) {
                    case 'br':
                      if (received == -1) {
                        received = 0;
                      }
                      received = int.parse(split[1]);
                      break;
                    default:
                      logger.warning('Unknown control message: $controlMsg');
                  }
                } catch (e, st) {
                  logger.shout(
                    'Caught (will rethrow) error: $e\nStack Trace:\n$st',
                  );
                  rethrow;
                }
              } catch (e) {
                logger.shout('$e while handling control message: $controlMsg');
              } finally {
                rcvBuffer.clear();
              }
            } else {
              rcvBuffer.addByte(data[element]);
            }
          }
        } finally {
          rcvMutex.release();
        }
      },
      onError: (err) {},
      onDone: () {},
    );
    logger.info('Starting pipe');

    int sent = 0;
    Completer endOfInput = Completer();
    stdin.listen(
      (data) {
        socket.add(data);
        sent += data.length;
      },
      onError: (err) {
        if (!endOfInput.isCompleted) {
          endOfInput.complete(err);
        }
      },
      onDone: () {
        if (!endOfInput.isCompleted) {
          endOfInput.complete();
        }
      },
    );

    logger.info('Waiting for end of stdin');
    await endOfInput.future;

    await socket.flush();

    logger.info('End of input; sent $sent bytes');

    logger.info('Waiting for all sent data to have been received');
    while (received < sent) {
      await Future.delayed(Duration(milliseconds: 10));
    }
    logger.info('All sent data has been received');
    await socket.close();
    await npt.close();
    await npt.done;

    logger.info('Done!');
    return 0;
  }
}
