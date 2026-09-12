import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/features/config/model/sshnpd_config_document.dart';
import 'package:noports_core/sshnpd.dart';
import 'package:yaml/yaml.dart';

void main() {
  final template = File('assets/sshnpd.template.yaml').readAsStringSync();

  test('bundled template matches the one shipped with sshnpd', () {
    final shipped = File(
      '../sshnoports/bundles/core/config/sshnpd.yaml',
    ).readAsStringSync();
    expect(template, shipped,
        reason: 'copy packages/dart/sshnoports/bundles/core/config/sshnpd.yaml '
            'to assets/sshnpd.template.yaml');
  });

  test('every schema field has a config key that parses', () {
    for (final f in ConfigSchema.fields) {
      expect(f.path, isNotEmpty, reason: f.option.name);
    }
  });

  test('template is unconfigured and reads back nulls', () {
    final doc = SshnpdConfigDocument.parse(template);
    expect(doc.isUnconfigured, isTrue);
    expect(doc.atsign, isNull);
    expect(doc.managers, isEmpty);
    expect(doc.permitOpen, isEmpty);
    expect(doc.getOption(SshnpdOption.verbose), isTrue);
    expect(doc.getOption(SshnpdOption.localSshdPort), 22);
  });

  test('setting scalar values keeps comments and re-parses', () {
    final doc = SshnpdConfigDocument.parse(template);
    doc.atsign = 'mydevice';
    doc.deviceName = 'office_pc';
    doc.setOption(SshnpdOption.localSshdPort, 2222);
    doc.setOption(SshnpdOption.verbose, false);

    final out = doc.source;
    // Comments from the template survive.
    expect(out, contains("# Don't do the following, as the '@' symbol"));
    expect(out, contains('# Set a device group name.'));

    final parsed = loadYaml(out) as YamlMap;
    expect(parsed['atsign']['atsign'], '@mydevice');
    expect(parsed['device']['name'], 'office_pc');
    expect(parsed['ssh']['sshd-port'], 2222);
    expect(parsed['runtime']['verbose'], false);

    // And through our own accessors.
    final again = SshnpdConfigDocument.parse(out);
    expect(again.atsign, '@mydevice');
    expect(again.isUnconfigured, isFalse);
  });

  test('setting list values on null keys produces block lists', () {
    final doc = SshnpdConfigDocument.parse(template);
    doc.managers = ['alice', '@bob'];
    doc.permitOpen = ['localhost:22', 'localhost:3389'];
    final parsed = loadYaml(doc.source) as YamlMap;
    expect(parsed['access']['managers'], ['@alice', '@bob']);
    expect(parsed['access']['permitopen'], ['localhost:22', 'localhost:3389']);
    expect(doc.managers, ['@alice', '@bob']);
    // Guard against yaml_edit swallowing following sections.
    expect(parsed['device'], isA<YamlMap>());
    expect(parsed['ssh'], isA<YamlMap>());
  });

  test('clearing values keeps the key present', () {
    final doc = SshnpdConfigDocument.parse(template);
    doc.managers = ['alice'];
    doc.managers = [];
    doc.atsign = '@x';
    doc.atsign = '';
    final parsed = loadYaml(doc.source) as YamlMap;
    expect(parsed['access'].containsKey('managers'), isTrue);
    expect(parsed['access']['managers'], isNull);
    expect(parsed['atsign']['atsign'], isNull);
  });

  test('missing keys and scalar parents are created', () {
    final doc = SshnpdConfigDocument.parse('atsign:\n  atsign: x\n');
    doc.set(['runtime', 'verbose'], true); // runtime map missing entirely
    doc.set(['atsign', 'root'], 'root.example.com'); // key missing in map
    final parsed = loadYaml(doc.source) as YamlMap;
    expect(parsed['runtime']['verbose'], true);
    expect(parsed['atsign']['root'], 'root.example.com');

    final doc2 = SshnpdConfigDocument.parse('access:\ndevice:\n  name: a\n');
    doc2.set(['access', 'managers'], ['@a']); // access is a null scalar
    final p2 = loadYaml(doc2.source) as YamlMap;
    expect(p2['access']['managers'], ['@a']);
    expect(p2['device']['name'], 'a');
  });

  test('tri-state strict can be set and cleared', () {
    final doc = SshnpdConfigDocument.parse(template);
    expect(doc.getOption(SshnpdOption.strict), isNull);
    doc.setOption(SshnpdOption.strict, true);
    expect(doc.getOption(SshnpdOption.strict), isTrue);
    doc.setOption(SshnpdOption.strict, null);
    expect(doc.getOption(SshnpdOption.strict), isNull);
  });

  group('validate', () {
    test('flags missing atsign and access', () {
      final doc = SshnpdConfigDocument.parse(template);
      final problems = doc.validate().map((p) => p.option).toList();
      expect(problems, contains(SshnpdOption.atsign));
      expect(problems, contains(SshnpdOption.managers));
    });

    test('passes a minimal good config', () {
      final doc = SshnpdConfigDocument.parse(template);
      doc.atsign = '@dev';
      doc.managers = ['@client'];
      expect(doc.validate(), isEmpty);
    });

    test('flags bad permitopen and port', () {
      final doc = SshnpdConfigDocument.parse(template);
      doc.atsign = '@dev';
      doc.policyManager = '@pol';
      doc.permitOpen = ['nohost', 'localhost:99999', '*:*', 'host:80'];
      doc.setOption(SshnpdOption.localSshdPort, 70000);
      final msgs = doc.validate().map((p) => p.message).join('\n');
      expect(msgs, contains('"nohost"'));
      expect(msgs, contains('"localhost:99999"'));
      expect(msgs, isNot(contains('"*:*"')));
      expect(msgs, isNot(contains('"host:80"')));
      expect(msgs, contains('Port must be'));
    });
  });
}
