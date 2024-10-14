/// Features which can be supported by the NoPorts Daemon
/// Do not change the names of existing features as this will cause
/// breaking changes across versions
enum DaemonFeature {
  /// daemon will accept ssh public keys sent by clients (i.e. daemon has been
  /// started with the `--sshpublickey` or `-s` flag)
  acceptsPublicKeys,

  /// authenticate when connecting to the Socket Rendezvous (sr)
  srAuth,

  /// End-to-end encrypt traffic sent via the SocketRendezvous (sr)
  srE2ee,

  /// Understands requests from clients for specific ports. Note that this
  /// does not mean that a daemon will **allow** a connection to that port,
  /// just that the daemon will understand the request. For example, a client
  /// could request to connect to port 80, and the daemon could allow it, but
  /// not allow connections to any other ports.
  supportsPortChoice,

  /// Understands and respects the 'timeout' value in an npt session request
  /// See also [NptParams.timeout]
  adjustableTimeout,
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
    }
  }
}
