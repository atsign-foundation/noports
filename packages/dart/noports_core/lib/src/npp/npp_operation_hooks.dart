import './models.dart';

/// Pre- hooks are called before the entity is put into the cached.
/// This is typically a good time to persist the entity into a database.
/// If the persistence is successful, the hook should complete normally and no exceptions should be thrown.
/// If the persistence fails, the hook should throw an exception to prevent the entity from being cached into the policy service's NppCache.
typedef PrePutClientHook = Future<void> Function(Client client);
typedef PrePutClientGroupHook = Future<void> Function(ClientGroup clientGroup);
typedef PrePutClientGroupMemberHook = Future<void> Function(ClientGroupMember clientGroupMember);
typedef PrePutDaemonHook = Future<void> Function(Daemon daemon);
typedef PrePutServiceHook = Future<void> Function(Service service);
typedef PrePutServiceACLHook = Future<void> Function(ServiceACL serviceACL);

/// Post- hooks are called after the entity has been put into the cache.
/// These hooks will only be called if the put operaiton was successful.
typedef PostPutClientHook = Future<void> Function(Client client);
typedef PostPutClientGroupHook = Future<void> Function(ClientGroup clientGroup);
typedef PostPutClientGroupMemberHook = Future<void> Function(ClientGroupMember clientGroupMember);
typedef PostPutDaemonHook = Future<void> Function(Daemon daemon);
typedef PostPutServiceHook = Future<void> Function(Service service);
typedef PostPutServiceACLHook = Future<void> Function(ServiceACL serviceACL);

/// If the hook is null, then it is simply not called and no action is taken.
class NppOperationHooks {
  PrePutClientHook? prePutClient; // This is called before the policy service is about to put the Client into the cache.
  PrePutClientGroupHook? prePutClientGroup; // This is called before the policy service is about to put the ClientGroup into the cache.
  PrePutClientGroupMemberHook? prePutClientGroupMember; // This is called before the policy service is about to put the ClientGroupMember into the cache.
  PrePutDaemonHook? prePutDaemon; // This is called before the policy service is about to put the Daemon into the cache.
  PrePutServiceHook? prePutService; // This is called before the policy service is about to put the Service into the cache.
  PrePutServiceACLHook? prePutServiceACL; // This is called before the policy service is about to put the ServiceACL into the cache.

  PostPutClientHook? postPutClient; // This is called after the policy service has put the Client into the cache.
  PostPutClientGroupHook? postPutClientGroup; // This is called after the policy service has put the ClientGroup into the cache.
  PostPutClientGroupMemberHook? postPutClientGroupMember; // This is called after the policy service has put the ClientGroupMember into the cache.
  PostPutDaemonHook? postPutDaemon; // This is called after the policy service has put the Daemon into the cache.
  PostPutServiceHook? postPutService; // This is called after the policy service has put the Service into the cache.
  PostPutServiceACLHook? postPutServiceACL; // This is called after the policy service has put the ServiceACL into the cache.

  NppOperationHooks({
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
