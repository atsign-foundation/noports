import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/sshnpd/sshnpd_config.dart';

class SshnpdParams extends AtsignParams {
  final String device;
  final String username;
  final String homeDirectory;
  final List<Atsign> managerAtsigns;
  final Atsign? policyManagerAtsign;
  final bool makeDeviceInfoVisible;
  final bool addSshPublicKeys;
  final SupportedSshClient sshClient;
  final int localSshdPort;
  final String sshPublicKeyPermissions;
  final String ephemeralPermissions;
  final SupportedSshAlgorithm sshAlgorithm;
  final String deviceGroup;
  final String permitOpen;
  final bool clearCachedPKs;
  final bool strict;

  //backwards compat.
  Atsign get deviceAtsign => atSign;

  SshnpdParams({
    required super.atSign,
    required super.atKeysFilePath,
    required super.passPhrase,
    required super.storagePath,
    required super.rootDomain,
    required super.verbose,
    required super.debug,
    required this.device,
    required this.username,
    required this.homeDirectory,
    required this.managerAtsigns,
    required this.policyManagerAtsign,
    required this.makeDeviceInfoVisible,
    required this.addSshPublicKeys,
    required this.sshClient,
    required this.localSshdPort,
    required this.sshPublicKeyPermissions,
    required this.ephemeralPermissions,
    required this.sshAlgorithm,
    required this.deviceGroup,
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
    Future<void> Function()? doctorCallback,
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

    if (c.value(SshnpdOption.doctor)) {
      await doctorCallback?.call();
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
      atSign: deviceAtsign,
      verbose: c.value(SshnpdOption.verbose),
      debug: c.value(SshnpdOption.debug),
      makeDeviceInfoVisible: makeDeviceInfoVisible,
      addSshPublicKeys: c.value(SshnpdOption.addSshPublicKey),
      sshClient: c.value(SshnpdOption.sshClient),
      rootDomain: c.value(SshnpdOption.rootServer),
      localSshdPort: c.value(SshnpdOption.localSshdPort),
      sshPublicKeyPermissions: normalizedPermissions,
      ephemeralPermissions: c
          .value(SshnpdOption.sshEphemeralPermissions)
          .join(","),
      sshAlgorithm: c.value(SshnpdOption.sshAlgorithm),
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
