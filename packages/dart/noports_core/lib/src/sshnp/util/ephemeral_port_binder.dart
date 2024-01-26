import 'package:meta/meta.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/src/common/io_types.dart';

mixin EphemeralPortBinder on SshnpCore {
  @visibleForTesting
  @protected
  Future<void> findLocalPortIfRequired() async {
    // find a spare local port
    if (localPort == 0) {
      logger.info('Finding a spare local port');
      try {
        ServerSocket serverSocket =
            await ServerSocket.bind(InternetAddress.loopbackIPv4, 0)
                .catchError((e) => throw e);
        localPort = serverSocket.port;
        await serverSocket.close().catchError((e) => throw e);
      } catch (e, s) {
        logger.info('Unable to find a spare local port');
        throw SshnpError('Unable to find a spare local port',
            error: e, stackTrace: s);
      }
    }
  }
}
