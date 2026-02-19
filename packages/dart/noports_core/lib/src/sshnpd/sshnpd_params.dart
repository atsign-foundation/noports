import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/sshnpd/sshnpd_config.dart';

class SshnpdParams {
  final String device;
  final String username;
  final String homeDirectory;
  final List<String> managerAtsigns;
  final String? policyManagerAtsign;
  final String atKeysFilePath;
  final String passPhrase;
  final String deviceAtsign;
  final bool verbose;
  final bool debug;
  final bool makeDeviceInfoVisible;
  final bool addSshPublicKeys;
  final SupportedSshClient sshClient;
  final String rootDomain;
  final int localSshdPort;
  final String sshPublicKeyPermissions;
  final String deviceGroup;
  final String storagePath;
  final String permitOpen;
  final bool clearCachedPKs;
  final bool strict;

  SshnpdParams({
    required this.device,
    required this.username,
    required this.homeDirectory,
    required this.managerAtsigns,
    required this.policyManagerAtsign,
    required this.atKeysFilePath,
    required this.passPhrase,
    required this.deviceAtsign,
    required this.verbose,
    required this.debug,
    required this.makeDeviceInfoVisible,
    required this.addSshPublicKeys,
    required this.sshClient,
    required this.rootDomain,
    required this.localSshdPort,
    required this.sshPublicKeyPermissions,
    required this.deviceGroup,
    required this.storagePath,
    required this.permitOpen,
    required this.clearCachedPKs,
    required this.strict,
  }) {
    if (invalidDeviceName(device)) {
      throw ArgumentError(invalidDeviceNameMsg);
    }
  }

  static Future<SshnpdParams> fromArgs(
    List<String> args, {
    void Function()? helpCallback,
    void Function()? versionCallback,
  }) async {
    // Arg check
    final Configuration c = Configuration<SshnpdOption>.resolveNoExcept(
      options: SshnpdOption.values,
      args: args,
      configBroker: SshnpdConfigBroker(),
    );

    if (c.value(SshnpdOption.version)) {
      versionCallback?.call();
    }

    if (c.value(SshnpdOption.help)) {
      helpCallback?.call();
    }

    if (c.errors.isNotEmpty) {
      throw ArgumentError(c.errors.first);
    }

    Atsign deviceAtsign = c.value(SshnpdOption.atsign).toAtsign();

    if (c.optionalValue(SshnpdOption.managers) == null &&
        c.optionalValue(SshnpdOption.policyManager) == null) {
      throw ArgumentError(
        'At least one of --managers and --policy-manager'
        ' options must be supplied.',
      );
    }
    String homeDirectory = getHomeDirectory()!;

    // Do we have a valid device name?
    String device = c.value(SshnpdOption.device);
    // First of all let's snakify it
    device = snakifyDeviceName(device);
    // and now check it against desired regex
    if (invalidDeviceName(device)) {
      throw ArgumentError(invalidDeviceNameMsg);
    }
    bool makeDeviceInfoVisible =
        !(c.optionalValue(SshnpdOption.hide) ?? !c.value(SshnpdOption.unHide));
    // Normalize/validate the sshPublicKeyPermissions
    String normalizedPermissions = c
        .value(SshnpdOption.sshPublicKeyPermissions)
        .map((e) => e.trim())
        .toList()
        .join(",");
    // don't remove newlines, since internal whitespace may be important to what they are trying to do
    if (RegExp(r'[\r\n]').hasMatch(normalizedPermissions)) {
      // bad input... newlines are dangerous
      throw ArgumentError(invalidSshKeyPermissionsMsg);
    }

    var permitOpen = c.optionalValue(SshnpdOption.permitOpen)?.join(",");
    // #1295 - if we have a policy-manager arg and no permit-open arg
    // then we set permit-open '*:*' (since the policy manager will
    // be taking care of decisions in any event)
    permitOpen ??= c.optionalValue(SshnpdOption.policyManager) == null
        ? DefaultSshnpdArgs.permitOpen
        : '*:*';

    final managers = c
        .optionalValue(SshnpdOption.managers)
        ?.map((m) => m.toAtsign())
        .toList();

    final Atsign? policyManagerAtsign = c
        .optionalValue(SshnpdOption.policyManager)
        ?.toAtsign();
    return SshnpdParams(
      device: device,
      username: getUserName(throwIfNull: true)!,
      homeDirectory: homeDirectory,
      managerAtsigns: managers ?? [],
      policyManagerAtsign: policyManagerAtsign,
      atKeysFilePath:
          c.optionalValue(SshnpdOption.keyfile) ??
          getDefaultAtKeysFilePath(homeDirectory, deviceAtsign),
      passPhrase: c.optionalValue(SshnpdOption.passPhrase) ?? "",
      deviceAtsign: deviceAtsign,
      verbose: c.value(SshnpdOption.verbose),
      debug: c.value(SshnpdOption.debug),
      makeDeviceInfoVisible: makeDeviceInfoVisible,
      addSshPublicKeys: c.value(SshnpdOption.addSshPublicKey),
      sshClient: c.value(SshnpdOption.sshClient),
      rootDomain: c.value(SshnpdOption.rootServer),
      localSshdPort: c.value(SshnpdOption.localSshdPort),
      sshPublicKeyPermissions: normalizedPermissions,
      deviceGroup: c.value(SshnpdOption.deviceGroup),
      storagePath:
          c.optionalValue(SshnpdOption.storagePath)?.path ??
          standardAtClientStoragePath(
            baseDir: homeDirectory,
            atSign: deviceAtsign,
            progName: 'sshnpd',
            uniqueID: device,
          ),
      permitOpen: permitOpen,
      clearCachedPKs: c.value(SshnpdOption.clearCachedPks),
      strict:
          c.optionalValue(SshnpdOption.strict) ?? policyManagerAtsign != null,
    );
  }
}
