import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// A process as the operating system lists it: its pid and its arguments,
/// program first.
class ListedProcess {
  final int pid;
  final List<String> args;

  const ListedProcess(this.pid, this.args);
}

/// Whether [processes] include one, other than [selfPid], that runs the
/// daemon [name] as `name ...` or `atsc name ...` without `--doctor`.
///
/// The program is the first argument with its directory removed; on
/// [windows] it is compared ignoring case and any `.exe` suffix.
bool isDaemonListed(
  Iterable<ListedProcess> processes,
  String name, {
  required int selfPid,
  required bool windows,
}) => processes.any(
  (p) => p.pid != selfPid && _runsDaemon(p.args, name, windows),
);

bool _runsDaemon(List<String> args, String name, bool windows) {
  if (args.isEmpty) return false;
  final program = _programName(args.first, windows);
  final int optionsFrom;
  if (program == (windows ? name.toLowerCase() : name)) {
    optionsFrom = 1;
  } else if (program == 'atsc' && args.length > 1 && args[1] == name) {
    optionsFrom = 2;
  } else {
    return false;
  }
  return !args.skip(optionsFrom).contains('--doctor');
}

String _programName(String program, bool windows) {
  if (!windows) return program.substring(program.lastIndexOf('/') + 1);
  final base = program
      .substring(program.lastIndexOf(RegExp(r'[\\/]')) + 1)
      .toLowerCase();
  return base.endsWith('.exe') ? base.substring(0, base.length - 4) : base;
}

/// The directory Linux lists its processes in.
const linuxProcDirectory = '/proc';

/// The macOS command listing each process's pid and command name, which `ps`
/// takes whole from its first argument.
const macOSCommandNameListing = ['ps', '-A', '-o', 'pid=,comm='];

/// The macOS command listing each process's pid and arguments joined by
/// spaces.
const macOSArgumentsListing = ['ps', '-A', '-o', 'pid=,args='];

/// Lists the processes in [proc], laid out as Linux's `/proc`, each by the
/// exact arguments in its NUL-separated `cmdline`; a process that exits or
/// cannot be read while listing is left out.
Future<List<ListedProcess>> listProcDirectory(Directory proc) async {
  final processes = <ListedProcess>[];
  await for (final entry in proc.list(followLinks: false)) {
    final pid = int.tryParse(path.basename(entry.path));
    if (pid == null) continue;
    final List<int> cmdline;
    try {
      cmdline = await File(path.join(entry.path, 'cmdline')).readAsBytes();
    } on FileSystemException {
      continue;
    }
    final args = utf8.decode(cmdline, allowMalformed: true).split('\x00');
    if (args.last.isEmpty) args.removeLast();
    processes.add(ListedProcess(pid, args));
  }
  return processes;
}

/// Joins the output of [macOSCommandNameListing] and [macOSArgumentsListing]
/// by pid: the program is the command name whole, and the other arguments are
/// the rest of the args split on whitespace. A process whose args do not
/// begin with its command name is listed by its command name alone.
List<ListedProcess> parsePsListing(String commandNames, String arguments) {
  final argumentsByPid = _pidColumn(arguments);
  return [
    for (final MapEntry(key: pid, value: program) in _pidColumn(
      commandNames,
    ).entries)
      if (argumentsByPid[pid] case final String line)
        ListedProcess(pid, [program, ..._argumentsAfter(program, line)]),
  ];
}

Map<int, String> _pidColumn(String output) => {
  for (final match in RegExp(
    r'^[ \t]*(\d+) (.*)$',
    multiLine: true,
  ).allMatches(output))
    if (int.tryParse(match.group(1)!) case final int pid) pid: match.group(2)!,
};

List<String> _argumentsAfter(String program, String line) {
  if (!line.startsWith(program)) return const [];
  final rest = line.substring(program.length);
  if (rest.isNotEmpty && !rest.startsWith(RegExp(r'\s'))) return const [];
  final trimmed = rest.trim();
  return trimmed.isEmpty ? const [] : trimmed.split(RegExp(r'\s+'));
}

/// Parses a JSON array of Win32_Process `ProcessId`, `Name` and
/// `CommandLine`: the program is the image `Name`, and the other arguments
/// are those after the command line's first token, so a process whose
/// command line is unreadable is listed by its image name alone. Output that
/// is not JSON lists nothing.
List<ListedProcess> parseWin32ProcessListing(String output) {
  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return [];
  }
  return [
    for (final entry
        in (decoded is List ? decoded : [decoded]).whereType<Map>())
      if (entry case {'ProcessId': final int pid, 'Name': final String image})
        ListedProcess(pid, [
          image,
          ..._argumentsAfterProgram(entry['CommandLine']),
        ]),
  ];
}

List<String> _argumentsAfterProgram(Object? commandLine) {
  if (commandLine is! String) return const [];
  final line = commandLine.trimLeft();
  final int programEnd;
  if (line.startsWith('"')) {
    final closingQuote = line.indexOf('"', 1);
    programEnd = closingQuote < 0 ? line.length : closingQuote + 1;
  } else {
    final whitespace = line.indexOf(RegExp(r'[ \t]'));
    programEnd = whitespace < 0 ? line.length : whitespace;
  }
  return _splitWindowsCommandLine(line.substring(programEnd));
}

List<String> _splitWindowsCommandLine(String commandLine) {
  final args = <String>[];
  final arg = StringBuffer();
  var quoted = false;
  var started = false;
  for (final char in commandLine.split('')) {
    if (char == '"') {
      quoted = !quoted;
      started = true;
    } else if (!quoted && (char == ' ' || char == '\t')) {
      if (started) args.add(arg.toString());
      arg.clear();
      started = false;
    } else {
      arg.write(char);
      started = true;
    }
  }
  if (started) args.add(arg.toString());
  return args;
}
