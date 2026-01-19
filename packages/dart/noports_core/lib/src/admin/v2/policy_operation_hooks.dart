import './models.dart';

typedef PrePutClientHook = Future<void> Function(Client client);
typedef PrePutClientGroupHook = Future<void> Function(ClientGroup clientGroup);
typedef PrePutClientGroupMemberHook = Future<void> Function(ClientGroupMember clientGroupMember);
typedef PrePutDaemonHook = Future<void> Function(Daemon daemon);
typedef PrePutServiceHook = Future<void> Function(Service service);
typedef PrePutServiceACLHook = Future<void> Function(ServiceACL serviceACL);

typedef PostPutClientHook = Future<void> Function(Client client);
typedef PostPutClientGroupHook = Future<void> Function(ClientGroup clientGroup);
typedef PostPutClientGroupMemberHook = Future<void> Function(ClientGroupMember clientGroupMember);
typedef PostPutDaemonHook = Future<void> Function(Daemon daemon);
typedef PostPutServiceHook = Future<void> Function(Service service);
typedef PostPutServiceACLHook = Future<void> Function(ServiceACL serviceACL);

class PolicyOperationHooks {
  final PrePutClientHook? prePutClient;
  final PrePutClientGroupHook? prePutClientGroup;
  final PrePutClientGroupMemberHook? prePutClientGroupMember;
  final PrePutDaemonHook? prePutDaemon;
  final PrePutServiceHook? prePutService;
  final PrePutServiceACLHook? prePutServiceACL;

  final PostPutClientHook? postPutClient;
  final PostPutClientGroupHook? postPutClientGroup;
  final PostPutClientGroupMemberHook? postPutClientGroupMember;
  final PostPutDaemonHook? postPutDaemon;
  final PostPutServiceHook? postPutService;
  final PostPutServiceACLHook? postPutServiceACL;

  const PolicyOperationHooks({
    this.prePutClient,
    this.prePutClientGroup,
    this.prePutClientGroupMember,
    this.prePutDaemon,
    this.prePutService,
    this.prePutServiceACL,
    this.postPutClient,
    this.postPutClientGroup,
    this.postPutClientGroupMember,
    this.postPutDaemon,
    this.postPutService,
    this.postPutServiceACL,
  });
}
