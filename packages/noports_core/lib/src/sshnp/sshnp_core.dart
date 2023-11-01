import 'dart:async';

import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;

import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/async_completion.dart';
import 'package:noports_core/src/common/async_initialization.dart';
import 'package:noports_core/src/common/at_client_bindings.dart';
import 'package:noports_core/src/sshnp/channels/sshnpd/sshnpd_channel.dart';
import 'package:noports_core/src/sshnp/channels/sshrvd/sshrvd_channel.dart';
import 'package:noports_core/src/sshnp/sshnp_device_list.dart';

import 'package:noports_core/sshnp.dart';

import 'package:noports_core/utils.dart';
import 'package:uuid/uuid.dart';

export 'forward_direction/sshnp_forward.dart';
export 'forward_direction/sshnp_forward_dart.dart';

export 'reverse_direction/sshnp_reverse.dart';
export 'reverse_direction/sshnp_reverse_impl.dart';
export 'reverse_direction/sshnp_legacy_impl.dart';

// If you've never seen an abstract implementation before, here it is :P
@protected
abstract class SshnpCore
    with AsyncInitialization, AsyncDisposal, AtClientBindings
    implements Sshnp {
  // * AtClientBindings members
  @override
  final AtSignLogger logger = AtSignLogger(' sshnp ');
  @override
  final AtClient atClient;

  // * Main Parameters
  @override
  final SshnpParams params;
  final String sessionId;
  final String namespace;

  // * Volatile State
  int localPort;
  AtSshKeyPair? identityKeyPair;

  // * Auxiliary classes
  @protected
  AtSSHKeyUtil get keyUtil;

  @protected
  SshrvdChannel get sshrvdChannel;

  @protected
  SshnpdChannel get sshnpdChannel;

  SshnpCore({
    required this.atClient,
    required this.params,
  })  : sessionId = Uuid().v4(),
        namespace = '${params.device}.sshnp',
        localPort = params.localPort {
    /// Set the logger level to shout
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;

    if (params.verbose) {
      logger.logger.level = Level.INFO;
    }

    /// Set the namespace to the device's namespace
    AtClientPreference preference =
        atClient.getPreferences() ?? AtClientPreference();
    preference.namespace = namespace;
    atClient.setPreferences(preference);
  }

  @override
  @mustCallSuper
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;
    logger.info('Initializing SSHNPCore');

    try {
      if (!(await atSignIsActivated(atClient, params.sshnpdAtSign))) {
        logger
            .severe('Device address ${params.sshnpdAtSign} is not activated.');
        throw ('Device address ${params.sshnpdAtSign} is not activated.');
      }
    } catch (e, s) {
      throw SshnpError(e, stackTrace: s);
    }

    // Start listening for response notifications from sshnpd
    logger.info('Subscribing to notifications on $sessionId.$namespace@');

    // TODO investigate if this is a problem on mobile
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

    // await sharePublicKeyWithSshnpdIfRequired().catchError((e, s) {
    //   throw SSHNPError(
    //     'Unable to share ssh public key with sshnpd',
    //     error: e,
    //     stackTrace: s,
    //   );
    // });

    // If host has an @ then contact the sshrvd service for some ports
    // if (host.startsWith('@')) {
    //   logger.info('Host is an atSign, fetching host and port from sshrvd');
    //   await getHostAndPortFromSshrvd().catchError((e, s) {
    //     throw SSHNPError(
    //       'Unable to get host and port from sshrvd',
    //       error: e,
    //       stackTrace: s,
    //     );
    //   });
    // }

    logger.finer('Base initialization complete');
    // N.B. Don't complete initialization here, subclasses will do that
    // This is in case they need to implement further initialization steps
  }

  @override
  Future<SshnpDeviceList> listDevices() => sshnpdChannel.listDevices();
}
