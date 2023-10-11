import 'package:args/args.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:test/test.dart';

void main() {
  group('ParserType', () {
    test('ParserType public API test', () {
      // abitrary values
      ParserType parserType = ParserType.all;
      ParseWhen parseWhen = ParseWhen.always;

      expect(parserType.allowList, isA<Iterable<ParseWhen>>());
      expect(parserType.denyList, isA<Iterable<ParseWhen>>());
      expect(parserType.shouldParse(parseWhen), isA<bool>());
    });

    group('ParserType.all', () {
      test('ParserType.all allowList test', () {
        expect(ParserType.all.allowList, contains(ParseWhen.always));
        expect(ParserType.all.allowList, contains(ParseWhen.commandLine));
        expect(ParserType.all.allowList, contains(ParseWhen.configFile));
      });

      test('ParserType.all denyList test', () {
        expect(ParserType.all.denyList, contains(ParseWhen.never));
      });

      test('ParserType.all shouldParse test', () {
        expect(ParserType.all.shouldParse(ParseWhen.always), isTrue);
        expect(ParserType.all.shouldParse(ParseWhen.commandLine), isTrue);
        expect(ParserType.all.shouldParse(ParseWhen.configFile), isTrue);
        expect(ParserType.all.shouldParse(ParseWhen.never), isFalse);
      });
    });

    group('ParserType.commandLine', () {
      test('ParserType.commandLine allowList test', () {
        expect(ParserType.commandLine.allowList, contains(ParseWhen.always));
        expect(ParserType.commandLine.allowList, contains(ParseWhen.commandLine));
        expect(ParserType.commandLine.allowList, isNot(contains(ParseWhen.configFile)));
      });

      test('ParserType.commandLine denyList test', () {
        expect(ParserType.commandLine.denyList, isNot(contains(ParseWhen.always)));
        expect(ParserType.commandLine.denyList, isNot(contains(ParseWhen.commandLine)));
        expect(ParserType.commandLine.denyList, contains(ParseWhen.configFile));
      });

      test('ParserType.commandLine shouldParse test', () {
        expect(ParserType.commandLine.shouldParse(ParseWhen.always), isTrue);
        expect(ParserType.commandLine.shouldParse(ParseWhen.commandLine), isTrue);
        expect(ParserType.commandLine.shouldParse(ParseWhen.configFile), isFalse);
        expect(ParserType.commandLine.shouldParse(ParseWhen.never), isFalse);
      });
    });

    group('ParserType.configFile', () {
      test('ParserType.configFile allowList test', () {
        expect(ParserType.configFile.allowList, contains(ParseWhen.always));
        expect(ParserType.configFile.allowList, contains(ParseWhen.configFile));
        expect(ParserType.configFile.allowList, isNot(contains(ParseWhen.commandLine)));
      });

      test('ParserType.configFile denyList test', () {
        expect(ParserType.configFile.denyList, isNot(contains(ParseWhen.always)));
        expect(ParserType.configFile.denyList, isNot(contains(ParseWhen.configFile)));
        expect(ParserType.configFile.denyList, contains(ParseWhen.commandLine));
      });

      test('ParserType.configFile shouldParse test', () {
        expect(ParserType.configFile.shouldParse(ParseWhen.always), isTrue);
        expect(ParserType.configFile.shouldParse(ParseWhen.commandLine), isFalse);
        expect(ParserType.configFile.shouldParse(ParseWhen.configFile), isTrue);
        expect(ParserType.configFile.shouldParse(ParseWhen.never), isFalse);
      });
    });
  });

  test('SSHNPArg public API test', () {
    SSHNPArg sshnpArg = SSHNPArg(name: 'name');

    expect(sshnpArg.format, isA<ArgFormat>());
    expect(sshnpArg.name, isA<String>());
    expect(sshnpArg.abbr, isA<String?>());
    expect(sshnpArg.help, isA<String?>());
    expect(sshnpArg.mandatory, isA<bool>());
    expect(sshnpArg.defaultsTo, isA<dynamic>());
    expect(sshnpArg.type, isA<ArgType>());
    expect(sshnpArg.allowed, isA<Iterable<String>?>());
    expect(sshnpArg.parseWhen, isA<ParseWhen>());
    expect(sshnpArg.aliases, isA<List<String>?>());

    expect(sshnpArg.bashName, isA<String>());

    expect(SSHNPArg.args, isA<List<SSHNPArg>>());
    expect(SSHNPArg.createArgParser(), isA<ArgParser>());
  });

  group('SSHNPArg final variables', () {
    test('SSHNPArg.name test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name');
      expect(sshnpArg.name, equals('name'));
    });

    test('SSHNPArg.abbr test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', abbr: 'n');
      expect(sshnpArg.abbr, equals('n'));
    });

    test('SSHNPArg.help test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', help: 'help');
      expect(sshnpArg.help, equals('help'));
    });

    test('SSHNPArg.mandatory test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', mandatory: true);
      expect(sshnpArg.mandatory, isTrue);
    });

    test('SSHNPArg.defaultsTo test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', defaultsTo: 'default');
      expect(sshnpArg.defaultsTo, equals('default'));
    });

    test('SSHNPArg.type test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', type: ArgType.string);
      expect(sshnpArg.type, equals(ArgType.string));
    });

    test('SSHNPArg.allowed test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', allowed: ['allowed']);
      expect(sshnpArg.allowed, equals(['allowed']));
    });

    test('SSHNPArg.parseWhen test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', parseWhen: ParseWhen.always);
      expect(sshnpArg.parseWhen, equals(ParseWhen.always));
    });

    test('SSHNPArg.aliases test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', aliases: ['alias']);
      expect(sshnpArg.aliases, equals(['alias']));
    });

    test('SSHNPArg.negatable test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', negatable: false);
      expect(sshnpArg.negatable, isFalse);
    });

    test('SSHNPArg.hide test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', hide: true);
      expect(sshnpArg.hide, isTrue);
    });

    test('SSHNPArg default values test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name');
      expect(sshnpArg.abbr, isNull);
      expect(sshnpArg.help, isNull);
      expect(sshnpArg.mandatory, isFalse);
      expect(sshnpArg.format, equals(ArgFormat.option));
      expect(sshnpArg.defaultsTo, isNull);
      expect(sshnpArg.type, equals(ArgType.string));
      expect(sshnpArg.allowed, isNull);
      expect(sshnpArg.parseWhen, equals(ParseWhen.always));
      expect(sshnpArg.aliases, isNull);
      expect(sshnpArg.negatable, isTrue);
      expect(sshnpArg.hide, isFalse);
    });
  });

  group('SSHNPArg getters', () {
    test('SSHNPArg.bashName test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name');
      expect(sshnpArg.bashName, equals('NAME'));
    });

    test('SSHNPArg.alistList test', () {
      SSHNPArg sshnpArg = SSHNPArg(name: 'name', aliases: ['alias'], abbr: 'a');
      expect(sshnpArg.aliasList, equals(['--name', '--alias', '-a']));
    });
  });

  group('SSHNPArg factory', () {
    test('SSHNPArg.noArg test', () {
      SSHNPArg sshnpArg = SSHNPArg.noArg();
      expect(sshnpArg.name, equals(''));
    });

    test('SSHNPArg.fromName test', () {
      SSHNPArg sshnpArg = SSHNPArg.fromName(SSHNPArg.fromArg.name);
      expect(sshnpArg.name, equals(SSHNPArg.fromArg.name));
    });

    test('SSHNPArg.fromBashName test', () {
      SSHNPArg sshnpArg = SSHNPArg.fromBashName(SSHNPArg.fromArg.bashName);
      expect(sshnpArg.name, equals(SSHNPArg.fromArg.name));
    });

    test('SSHNPArg.fromName no match test', () {
      SSHNPArg sshnpArg = SSHNPArg.fromName('no match');
      expect(sshnpArg.name, equals(''));
    });

    test('SSHNPArg.fromBashName no match test', () {
      SSHNPArg sshnpArg = SSHNPArg.fromBashName('no match');
      expect(sshnpArg.name, equals(''));
    });
  });
}
