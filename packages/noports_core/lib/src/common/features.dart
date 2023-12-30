/// Features which can be supported by the NoPorts Daemon
enum DaemonFeatures {
  /// authenticate when connecting to the Socket Rendezvous (sr)
  srAuth,

  /// End-to-end encrypt traffic sent via the SocketRendezvous (sr)
  srE2ee,
}
