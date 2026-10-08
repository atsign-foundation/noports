import 'package:version/version.dart';

/// Features which can be supported by the NoPorts Daemon
/// Do not change the names of existing features as this will cause
/// breaking changes across versions
enum DaemonFeature {
  /// daemon will accept ssh public keys sent by clients (i.e. daemon has been
  /// started with the `--sshpublickey` or `-s` flag)
  acceptsPublicKeys('1.0.0'),

  /// authenticate when connecting to the Socket Rendezvous (sr)
  srAuth('1.1.0'),

  /// End-to-end encrypt traffic sent via the SocketRendezvous (sr)
  srE2ee('1.1.0'),

  /// Understands requests from clients for specific ports. Note that this
  /// does not mean that a daemon will **allow** a connection to that port,
  /// just that the daemon will understand the request. For example, a client
  /// could request to connect to port 80, and the daemon could allow it, but
  /// not allow connections to any other ports.
  supportsPortChoice('1.2.0'),

  /// Understands and respects the 'timeout' value in an npt session request
  /// See also [NptParams.timeout]
  adjustableTimeout('1.3.0'),

  /// Can handle heartbeat messages being sent over the control channel.
  /// See also [NptParams.controlChannelHeartbeat]
  controlChannelHeartbeats('1.4.0'),

  /// Understands [RelayAuthMode.escr]
  supportsRamEscr('1.4.0'),

  /// Separate keys & IVs for client-to-server and server-to-client
  twinKeys('1.5.0');

  /// The version of the NoPorts control protocol which introduced this feature.
  Version get since => Version.parse(_since);
  final String _since;

  const DaemonFeature(this._since);

  /// The latest version amongst all of the features supported.
  static Version? _latestVersion;

  static Version get latestVersion {
    if (_latestVersion != null) {
      return _latestVersion!;
    }

    Version v = Version.parse('0.0.0');
    for (final f in DaemonFeature.values) {
      if (f.since > v) {
        v = f.since;
      }
    }
    _latestVersion = v;
    return v;
  }
}

extension FeatureDescription on DaemonFeature {
  String get description {
    switch (this) {
      case DaemonFeature.acceptsPublicKeys:
        return 'accept ssh public keys from the client';
      case DaemonFeature.srAuth:
        return 'authenticate to the socket rendezvous';
      case DaemonFeature.srE2ee:
        return 'encrypt traffic to the socket rendezvous';
      case DaemonFeature.supportsPortChoice:
        return 'support requests for specific device ports';
      case DaemonFeature.adjustableTimeout:
        return 'support the \'timeout\' value in npt session requests';
      case DaemonFeature.controlChannelHeartbeats:
        return 'handle heartbeat messages being send over the control channel';
      case DaemonFeature.supportsRamEscr:
        return 'support the \'ESCR\' relay auth mode';
      case DaemonFeature.twinKeys:
        return 'support separate keys for each direction';
    }
  }
}
