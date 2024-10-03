import 'package:args/args.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:test/test.dart';

void main() {
  group('ParserType', () {
    test('public API test', () {
      // arbitrary values
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
        expect(
            ParserType.commandLine.allowList, contains(ParseWhen.commandLine));
        expect(ParserType.commandLine.allowList,
            isNot(contains(ParseWhen.configFile)));
      });

      test('ParserType.commandLine denyList test', () {
        expect(
            ParserType.commandLine.denyList, isNot(contains(ParseWhen.always)));
        expect(ParserType.commandLine.denyList,
            isNot(contains(ParseWhen.commandLine)));
        expect(ParserType.commandLine.denyList, contains(ParseWhen.configFile));
      });

      test('ParserType.commandLine shouldParse test', () {
        expect(ParserType.commandLine.shouldParse(ParseWhen.always), isTrue);
        expect(
            ParserType.commandLine.shouldParse(ParseWhen.commandLine), isTrue);
        expect(
            ParserType.commandLine.shouldParse(ParseWhen.configFile), isFalse);
        expect(ParserType.commandLine.shouldParse(ParseWhen.never), isFalse);
      });
    });

    group('ParserType.configFile', () {
      test('ParserType.configFile allowList test', () {
        expect(ParserType.configFile.allowList, contains(ParseWhen.always));
        expect(ParserType.configFile.allowList, contains(ParseWhen.configFile));
        expect(ParserType.configFile.allowList,
            isNot(contains(ParseWhen.commandLine)));
      });

      test('ParserType.configFile denyList test', () {
        expect(
            ParserType.configFile.denyList, isNot(contains(ParseWhen.always)));
        expect(ParserType.configFile.denyList,
            isNot(contains(ParseWhen.configFile)));
        expect(ParserType.configFile.denyList, contains(ParseWhen.commandLine));
      });

      test('ParserType.configFile shouldParse test', () {
        expect(ParserType.configFile.shouldParse(ParseWhen.always), isTrue);
        expect(
            ParserType.configFile.shouldParse(ParseWhen.commandLine), isFalse);
        expect(ParserType.configFile.shouldParse(ParseWhen.configFile), isTrue);
        expect(ParserType.configFile.shouldParse(ParseWhen.never), isFalse);
      });
    });
  });

  group('SshnpArg', () {
    test('public API test', () {
      SshnpArg sshnpArg = SshnpArg(name: 'name');

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

      expect(SshnpArg.args, isA<List<SshnpArg>>());
      expect(SshnpArg.createArgParser(), isA<ArgParser>());
    });

    group('SshnpArg final variables', () {
      test('SshnpArg.name test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name');
        expect(sshnpArg.name, equals('name'));
      });

      test('SshnpArg.abbr test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', abbr: 'n');
        expect(sshnpArg.abbr, equals('n'));
      });

      test('SshnpArg.help test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', help: 'help');
        expect(sshnpArg.help, equals('help'));
      });

      test('SshnpArg.mandatory test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', mandatory: true);
        expect(sshnpArg.mandatory, isTrue);
      });

      test('SshnpArg.defaultsTo test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', defaultsTo: 'default');
        expect(sshnpArg.defaultsTo, equals('default'));
      });

      test('SshnpArg.type test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', type: ArgType.string);
        expect(sshnpArg.type, equals(ArgType.string));
      });

      test('SshnpArg.allowed test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', allowed: ['allowed']);
        expect(sshnpArg.allowed, equals(['allowed']));
      });

      test('SshnpArg.parseWhen test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', parseWhen: ParseWhen.always);
        expect(sshnpArg.parseWhen, equals(ParseWhen.always));
      });

      test('SshnpArg.aliases test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', aliases: ['alias']);
        expect(sshnpArg.aliases, equals(['alias']));
      });

      test('SshnpArg.negatable test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', negatable: false);
        expect(sshnpArg.negatable, isFalse);
      });

      test('SshnpArg.hide test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name', hide: true);
        expect(sshnpArg.hide, isTrue);
      });

      test('SshnpArg default values test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name');
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

    group('SshnpArg getters', () {
      test('SshnpArg.bashName test', () {
        SshnpArg sshnpArg = SshnpArg(name: 'name');
        expect(sshnpArg.bashName, equals('NAME'));
      });

      test('SshnpArg.alistList test', () {
        SshnpArg sshnpArg =
            SshnpArg(name: 'name', aliases: ['alias'], abbr: 'a');
        expect(sshnpArg.aliasList, equals(['--name', '--alias', '-a']));
      });
    });

    group('SshnpArg factory', () {
      test('SshnpArg.noArg test', () {
        SshnpArg sshnpArg = SshnpArg.noArg();
        expect(sshnpArg.name, equals(''));
      });

      test('SshnpArg.fromName test', () {
        SshnpArg sshnpArg = SshnpArg.fromName(SshnpArg.fromArg.name);
        expect(sshnpArg.name, equals(SshnpArg.fromArg.name));
      });

      test('SshnpArg.fromBashName test', () {
        SshnpArg sshnpArg = SshnpArg.fromBashName(SshnpArg.fromArg.bashName);
        expect(sshnpArg.name, equals(SshnpArg.fromArg.name));
      });

      test('SshnpArg.fromName no match test', () {
        SshnpArg sshnpArg = SshnpArg.fromName('no match');
        expect(sshnpArg.name, equals(''));
      });

      test('SshnpArg.fromBashName no match test', () {
        SshnpArg sshnpArg = SshnpArg.fromBashName('no match');
        expect(sshnpArg.name, equals(''));
      });
    });
  });
}
