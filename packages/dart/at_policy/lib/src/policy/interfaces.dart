import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:at_policy/src/policy/params.dart';
import 'package:at_policy/src/policy/impl.dart';
import 'package:at_policy/src/policy/policy_models.dart';

abstract class PolicyRequestHandler {
  Future<PolicyResponse> doAuthCheck(PolicyRequest authCheckRequest);
}

/// - Listens for authorization check requests from sshnp daemons
/// - Checks if the clientAtSign is currently authorized to access
///   the sshnpd atSign and device
/// - Responds accordingly
abstract class PolicyService implements AtRpcCallbacks {
  abstract final AtSignLogger logger;

  /// The [AtClient] used to communicate with SSHNPDs
  abstract AtClient atClient;

  // ====================================================================
  // Final instance variables, injected via constructor
  // ====================================================================
  /// The home directory on this host
  abstract final String homeDirectory;

  /// The home directory on this host
  abstract final String baseNamespace;

  String get authorizerAtsign;

  String get loggingAtsign;

  Set<String> get deviceAtsigns;

  PolicyRequestHandler get handler;

  static Future<PolicyService> fromCommandLineArgs(
    List<String> args, {
    required PolicyRequestHandler handler,
    AtClient? atClient,
    FutureOr<AtClient> Function(PolicyServiceParams)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
    Set<String>? daemonAtsigns,
  }) async {
    return PolicyServiceImpl.fromCommandLineArgs(
      args,
      handler: handler,
      atClient: atClient,
      atClientGenerator: atClientGenerator,
      usageCallback: usageCallback,
      daemonAtsigns: daemonAtsigns,
    );
  }

  /// Starts the sshnpa service
  Future<void> run();
}

abstract interface class PolicyAPI {
  /// initialize once it's been created
  Future<void> init();

  /// The in-memory groups map. Not for external use.
  @visibleForTesting
  Map<String, UserGroup> get groups;

  /// The in-memory device daemons map. Not for external use.
  @visibleForTesting
  Map<String, DeviceInfo> get deviceInfos;

  /// The in-memory list of log events. Not for external use.
  @visibleForTesting
  List<dynamic> get logEvents;

  Stream<String> get eventStream;

  /// Fetch some log events
  Future<List<PolicyLogEvent>> getLogEvents(
      {required int from, required int to});

  /// Get (some of) the permission groups known to this policy service.
  /// Method rather than getter, as we will add query parameters later
  Future<List<UserGroup>> getUserGroups();

  Future<DeviceInfo> createDevice(DeviceInfo deviceInfo);

  Future<List<DeviceInfo>> getDevices();

  Future<void> deleteDevices();

  /// Get a group object by its ID
  Future<UserGroup?> getUserGroup(String id);

  /// Create a group. Must not already have an `id`
  Future<UserGroup> createUserGroup(UserGroup group);

  /// Update a group. Must already have an `id`
  Future<void> updateUserGroup(UserGroup group);

  /// Delete a group.
  /// Return true if deleted, false if not.
  Future<bool> deleteUserGroup(String id);

  /// Get the list of groups of which this user is a member.
  Future<List<UserGroup>> getGroupsForUser(String atSign);

  String get policyAtSign;

  Set<String> get daemonAtSigns;

  factory PolicyAPI.inAtClient({
    required String policyAtSign,
    required AtClient atClient,
  }) {
    return PolicyApiWithAtClient(
      policyAtSign: policyAtSign,
      atClient: atClient,
    );
  }

  factory PolicyAPI.inMemory({
    required String policyAtSign,
  }) {
    return PolicyApiInMemory(
      policyAtSign: policyAtSign,
    );
  }
}
