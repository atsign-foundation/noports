/// Features which can be supported by the NoPorts Daemon
enum DaemonFeatures {
  /// daemon will accept public keys sent by clients (i.e. daemon has been
  /// started with the `--sshpublickey` or `-s` flag)
  acceptsPublicKeys,

  /// authenticate when connecting to the Socket Rendezvous (sr)
  srAuth,

  /// End-to-end encrypt traffic sent via the SocketRendezvous (sr)
  srE2ee,
}
