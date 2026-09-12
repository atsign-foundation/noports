import 'package:noports_core/sshnpd.dart';

/// Which part of the form a field belongs to. Order here is display order.
enum ConfigSection {
  atsign('Device atSign'),
  access('Access control'),
  device('Device'),
  ssh('SSH'),
  runtime('Runtime');

  const ConfigSection(this.title);
  final String title;
}

enum FieldKind {
  text,
  atsign,
  password,
  filePath,
  dirPath,
  integer,
  boolean,

  /// A flag whose absence means "let the daemon decide". Rendered as a
  /// three-way choice: Default / On / Off.
  triStateBoolean,
  stringList,
  atsignList,
  choice,
}

/// One editable setting in sshnpd.yaml.
///
/// The YAML path and daemon-side semantics come from [option], the matching
/// entry of [SshnpdOption] in noports_core, so help text and defaults stay
/// in sync with the daemon automatically. Only presentation (label, kind,
/// section, advanced) is decided here.
class ConfigField {
  const ConfigField({
    required this.option,
    required this.label,
    required this.kind,
    required this.section,
    this.description,
    this.required = false,
    this.advanced = false,
    this.choices = const [],
    this.placeholder,
  });

  final SshnpdOption option;
  final String label;
  final FieldKind kind;
  final ConfigSection section;

  /// Overrides the daemon's help text when that reads badly in a form.
  final String? description;
  final bool required;

  /// Hidden until the user asks for advanced settings.
  final bool advanced;
  final List<String> choices;
  final String? placeholder;

  /// Path inside the YAML document, e.g. `['atsign', 'atsign']`.
  List<String> get path {
    final key = option.option.configKey;
    if (key == null) {
      throw StateError('${option.name} has no configKey');
    }
    return key.split('/').where((s) => s.isNotEmpty).toList();
  }

  String get help => description ?? option.option.helpText ?? '';

  Object? get defaultValue => option.option.defaultsTo;

  int? get min => option == SshnpdOption.localSshdPort ? 1 : null;
  int? get max => option == SshnpdOption.localSshdPort ? 65535 : null;
}

/// The whole form, in display order. Add a row here to expose a new daemon
/// option; nothing else needs to change.
class ConfigSchema {
  ConfigSchema._();

  static const List<ConfigField> fields = [
    // Device atSign
    ConfigField(
      option: SshnpdOption.atsign,
      label: 'Device atSign',
      kind: FieldKind.atsign,
      section: ConfigSection.atsign,
      description: 'The atSign this device runs as. Its keys must be present '
          'on this machine (see the Keys tab).',
      required: true,
      placeholder: '@mydevice_np',
    ),
    ConfigField(
      option: SshnpdOption.keyfile,
      label: 'Keys file',
      kind: FieldKind.filePath,
      section: ConfigSection.atsign,
      description: 'Path to the .atKeys file for the device atSign. Leave '
          'empty to use the service account\'s ~/.atsign/keys directory. '
          'Importing keys on the Keys tab fills this in for you.',
    ),
    ConfigField(
      option: SshnpdOption.passPhrase,
      label: 'Keys passphrase',
      kind: FieldKind.password,
      section: ConfigSection.atsign,
      description: 'Only needed if the .atKeys file is passphrase protected.',
      advanced: true,
    ),
    ConfigField(
      option: SshnpdOption.rootServer,
      label: 'atDirectory (root server)',
      kind: FieldKind.text,
      section: ConfigSection.atsign,
      description: 'Leave as root.atsign.org unless you host your own '
          'atSigns. Use proxy:host:port to go through a proxy.',
      advanced: true,
      placeholder: 'root.atsign.org',
    ),

    // Access control
    ConfigField(
      option: SshnpdOption.managers,
      label: 'Manager atSigns',
      kind: FieldKind.atsignList,
      section: ConfigSection.access,
      description: 'Client atSigns allowed to connect to this device. At '
          'least one manager or a policy atSign is required.',
      placeholder: '@myclient',
    ),
    ConfigField(
      option: SshnpdOption.policyManager,
      label: 'Policy atSign',
      kind: FieldKind.atsign,
      section: ConfigSection.access,
      description: 'Optional. An atSign running a NoPorts policy service '
          'that decides who may connect. Managers above bypass policy.',
      placeholder: '@mypolicy',
    ),
    ConfigField(
      option: SshnpdOption.permitOpen,
      label: 'Permitted destinations',
      kind: FieldKind.stringList,
      section: ConfigSection.access,
      description: 'host:port pairs clients may reach through this device. '
          'Empty means localhost:22 and localhost:3389, or *:* when a policy '
          'atSign is set.',
      placeholder: 'localhost:3389',
    ),

    // Device
    ConfigField(
      option: SshnpdOption.device,
      label: 'Device name',
      kind: FieldKind.text,
      section: ConfigSection.device,
      description: 'Name clients use to pick this device when several share '
          'one atSign. Letters, numbers, underscore and dash only.',
      placeholder: 'default',
    ),
    ConfigField(
      option: SshnpdOption.deviceGroup,
      label: 'Device group',
      kind: FieldKind.text,
      section: ConfigSection.device,
      description: 'Optional group name used by policy services for fleet '
          'management.',
      advanced: true,
    ),
    ConfigField(
      option: SshnpdOption.hide,
      label: 'Hide from managers',
      kind: FieldKind.boolean,
      section: ConfigSection.device,
      description: 'Do not advertise this device\'s details to manager '
          'atSigns. It still answers pings.',
      advanced: true,
    ),

    // SSH
    ConfigField(
      option: SshnpdOption.localSshdPort,
      label: 'Local sshd port',
      kind: FieldKind.integer,
      section: ConfigSection.ssh,
      description: 'Port the SSH server on this machine listens on.',
    ),
    ConfigField(
      option: SshnpdOption.addSshPublicKey,
      label: 'Add client public keys to authorized_keys',
      kind: FieldKind.boolean,
      section: ConfigSection.ssh,
      description: 'Convenience for single-user devices. Not recommended in '
          'shared or enterprise settings.',
    ),
    ConfigField(
      option: SshnpdOption.sshClient,
      label: 'SSH client',
      kind: FieldKind.choice,
      section: ConfigSection.ssh,
      choices: ['openssh', 'dart'],
      description: 'openssh uses the ssh binary on PATH (recommended). dart '
          'uses the built-in client.',
      advanced: true,
    ),
    ConfigField(
      option: SshnpdOption.sshAlgorithm,
      label: 'SSH key algorithm',
      kind: FieldKind.choice,
      section: ConfigSection.ssh,
      choices: ['ed25519', 'rsa'],
      advanced: true,
    ),
    ConfigField(
      option: SshnpdOption.sshPublicKeyPermissions,
      label: 'authorized_keys options for client keys',
      kind: FieldKind.stringList,
      section: ConfigSection.ssh,
      advanced: true,
      placeholder: 'no-agent-forwarding',
    ),
    ConfigField(
      option: SshnpdOption.sshEphemeralPermissions,
      label: 'authorized_keys options for ephemeral keys',
      kind: FieldKind.stringList,
      section: ConfigSection.ssh,
      advanced: true,
      placeholder: 'PermitOpen="localhost:80"',
    ),

    // Runtime
    ConfigField(
      option: SshnpdOption.verbose,
      label: 'Verbose logging',
      kind: FieldKind.boolean,
      section: ConfigSection.runtime,
      description: 'Recommended. Logs INFO and above to the service log.',
    ),
    ConfigField(
      option: SshnpdOption.debug,
      label: 'Debug logging',
      kind: FieldKind.boolean,
      section: ConfigSection.runtime,
      description: 'Very noisy. Turn on only while troubleshooting.',
      advanced: true,
    ),
    ConfigField(
      option: SshnpdOption.strict,
      label: 'Strict request verification',
      kind: FieldKind.triStateBoolean,
      section: ConfigSection.runtime,
      advanced: true,
    ),
    ConfigField(
      option: SshnpdOption.storagePath,
      label: 'Local storage directory',
      kind: FieldKind.dirPath,
      section: ConfigSection.runtime,
      advanced: true,
    ),
    ConfigField(
      option: SshnpdOption.clearCachedPks,
      label: 'Clear cached public keys on start',
      kind: FieldKind.boolean,
      section: ConfigSection.runtime,
      description: 'Set after resetting one of your atSigns so the daemon '
          'picks up its new public key. Turn off again afterwards.',
      advanced: true,
    ),
  ];

  static ConfigField byOption(SshnpdOption option) =>
      fields.firstWhere((f) => f.option == option);

  static Iterable<ConfigField> inSection(ConfigSection s) =>
      fields.where((f) => f.section == s);
}
