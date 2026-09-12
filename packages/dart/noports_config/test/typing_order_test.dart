import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/features/config/model/sshnpd_config_document.dart';
import 'package:noports_core/sshnpd.dart';

void main() {
  final template = File('assets/sshnpd.template.yaml').readAsStringSync();
  final inputs = {
    SshnpdOption.atsign: '@ssh_1',
    SshnpdOption.device: 'tarial',
    SshnpdOption.deviceGroup: 'none',
  };

  List<List<T>> perms<T>(List<T> l) => l.length <= 1
      ? [l]
      : [
          for (var i = 0; i < l.length; i++)
            for (final rest in perms([...l]..removeAt(i))) [l[i], ...rest],
        ];

  test('any typing order of atsign, device name and group works key by key', () {
    for (final order in perms(inputs.keys.toList())) {
      final doc = SshnpdConfigDocument.parse(template);
      for (final o in order) {
        final f = ConfigSchema.byOption(o);
        var typed = '';
        for (final ch in inputs[o]!.split('')) {
          typed += ch;
          doc.set(f.path, typed);
          expect(doc.get(f.path), typed, reason: 'order $order while typing "$typed"');
        }
      }
      expect(doc.atsign, '@ssh_1', reason: 'order $order');
      expect(doc.deviceName, 'tarial');
      expect(doc.deviceGroup, 'none');
      final msgs = doc.validate().map((p) => p.message).toList();
      expect(msgs, isNot(contains('A device atSign is required.')), reason: 'order $order');
      expect(msgs.where((m) => m.contains('Device name')), isEmpty);
    }
  });
}
