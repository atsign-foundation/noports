import 'package:noports_core/utils.dart';
import 'package:test/test.dart';

void main() {
  group('formatCliHelp', () {
    const String optionLine = '-a, --atsign (mandatory)    The atSign to use';
    const String continuationLine =
        '                            (defaults to "@alice")';

    test('formats help in the GNU layout which help2man can parse', () {
      final String help = formatCliHelp(
        description: 'Does a thing.',
        optionsUsage: '$optionLine\n$continuationLine',
      );
      final List<String> lines = help.split('\n');
      expect(lines[0], matches(RegExp(r'^Usage: \S+ \[options\]$')));
      expect(lines[1], isEmpty);
      expect(lines[2], 'Does a thing.');
      expect(lines[3], isEmpty);
      expect(lines[4], 'Options:');
      // Options must be indented so that help2man recognises them as
      // options rather than running them together as plain text.
      expect(lines[5], '  $optionLine');
      expect(lines[6], '  $continuationLine');
      // Ends with exactly one trailing newline
      expect(help, endsWith('$continuationLine\n'));
    });

    test('honours a custom synopsis', () {
      final String help = formatCliHelp(
        description: 'Does a thing.',
        optionsUsage: optionLine,
        synopsis: '-a <atsign> [options]',
      );
      expect(
        help.split('\n')[0],
        matches(RegExp(r'^Usage: \S+ -a <atsign> \[options\]$')),
      );
    });

    test('gives option group headings a paragraph of their own', () {
      // sshnpd's usage contains group headings at column zero, e.g.
      // "Runtime Options". help2man absorbs the options following a heading
      // into a run-together block of text unless the heading is separated
      // from them by a blank line.
      final String help = formatCliHelp(
        description: 'Does a thing.',
        optionsUsage:
            'Runtime Options\n'
            '$optionLine\n'
            '\n'
            'atSign Options\n'
            '$optionLine',
      );
      final List<String> lines = help.split('\n');
      expect(lines[5], isEmpty);
      expect(lines[6], 'Runtime Options:');
      expect(lines[7], isEmpty);
      expect(lines[8], '  $optionLine');
      expect(lines[9], isEmpty);
      expect(lines[10], 'atSign Options:');
      expect(lines[11], isEmpty);
      expect(lines[12], '  $optionLine');
    });

    test('does not indent blank lines in the options usage', () {
      final String help = formatCliHelp(
        description: 'Does a thing.',
        optionsUsage: '$optionLine\n\n$continuationLine',
      );
      final List<String> lines = help.split('\n');
      expect(lines[6], isEmpty);
    });
  });
}
