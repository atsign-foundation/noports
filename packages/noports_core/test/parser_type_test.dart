import 'package:noports_core/sshnp_params.dart';
import 'package:test/test.dart';

void main() {
  group('ParserType public API', () {
    // abitrary values
    ParserType parserType = ParserType.all;
    ParseWhen parseWhen = ParseWhen.always;

    expect(parserType.allowList, anything);
    expect(parserType.denyList, anything);
    expect(parserType.shouldParse(parseWhen), anything);
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
}
