import 'package:test/test.dart';
import 'package:args/args.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';
import 'package:sshnoports/shared/utils.dart';

void main(){
  group('args parser test', () {
    test('test mandatory args', () {
      ArgParser parser = SSHNPD.createArgParser();
      
      List<String> args = [];
      expect(() => parser.parse(args)['atsign'], throwsA(isA<ArgumentError>()));

      args.addAll(['-a','@bob']);
      expect(parser.parse(args)['atsign'], '@bob');
      expect(() => parser.parse(args)['manager'], throwsA(isA<ArgumentError>()));

      args.addAll(['-m','@alice']);
      expect(parser.parse(args)['atsign'], '@bob');
      expect(parser.parse(args)['manager'], '@alice');
    });

    test('test parsed args with only mandatory provided', () {
      List<String> args = [];

      args.addAll(['-a', '@bob']);
      args.addAll(['-m', '@alice']);

      var p = SSHNPD.parseSSHNPDParams(args);

      expect(p.deviceAtsign, '@bob');
      expect(p.managerAtsign, '@alice');

      expect(p.device, 'default');
      expect(p.username, getUserName(throwIfNull: true));
      expect(p.homeDirectory, getHomeDirectory(throwIfNull:true));
      expect(p.verbose, false);
      expect(p.atKeysFilePath, getDefaultAtKeysFilePath(p.homeDirectory, p.deviceAtsign));
    });

    test('test parsed args with non-mandatory args provided', () {
      List<String> args = [];

      args.addAll(['-a', '@bob']);
      args.addAll(['-m', '@alice']);
      
      args.addAll([
        '-d', 'device',
        '-u',
        '-v',
        '-s',
        '-u',
      ]);


      var p = SSHNPD.parseSSHNPDParams(args);

      expect(p.deviceAtsign, '@bob');
      expect(p.managerAtsign, '@alice');

      expect(p.device, 'device');
      expect(p.username, getUserName(throwIfNull: true));
      expect(p.homeDirectory, getHomeDirectory(throwIfNull:true));
      expect(p.verbose, true);
      expect(p.atKeysFilePath, getDefaultAtKeysFilePath(p.homeDirectory, p.deviceAtsign));
    });
  });
}