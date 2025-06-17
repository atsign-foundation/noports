import 'dart:io' show exit;

import 'package:args/args.dart' show ArgParser, ArgResults;
import 'package:npt_flutter/constants.dart';

ArgParser createArgParser() {
  var parser = ArgParser();
  parser.addFlag("help", abbr: "h");
  parser.addMultiOption(
    "register-root",
    help:
        "Register a custom root domain which can be used by the app. Key:value pair objects, separated by ';', with entries separated by ','",
    valueHelp:
        'e.g. \'domain:root.atsign.org;registrar-url:my.atsign.com;description:Atsign\'s root\',domain:vip.ve.atsign.zone;description:development environment',
  );
  parser.addFlag(
    "include-default-roots",
    help: "Include the default root domains provided by Atsign.",
    defaultsTo: true,
    negatable: true,
  );
  return parser;
}

// printing should be allowed from this function, we want users to be able to
// see when their invocation went wrong
ArgResults parseArgsAndHandleConstants(ArgParser parser, List<String> args) {
  final ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    // ignore: avoid_print
    print("Failed to parse command-line invocation: $e");
    rethrow;
  }

  if (results["help"]) {
    // ignore: avoid_print
    print(parser.usage);
    exit(0);
  }
  if (results["include-default-roots"]) {
    Constants.registerDefaultRootDomains();
  }

  for (String entry in results["register-root"]) {
    // First parse the entry
    Map<String, String?> root = {};
    var fields = entry.split(";");
    for (var field in fields) {
      var parts = field.split(":");
      if (parts.length != 2) {
        // ignore: avoid_print
        print("Failed to register root, invalid entry: $entry");
        continue;
      }
      root[parts[0]] = parts[1];
    }

    // Then validate the entry to ensure mandatory fields are set
    const List<String> mandatory = ["domain", "description"];
    for (var field in mandatory) {
      if (root[field] is! String) {
        // ignore: avoid_print
        print(
            "Failed to register root, mandatory field $field not in entry: $entry");
        continue;
      }
    }

    Constants.registerRootDomain(root["domain"]!, (
      description: root["description"]!,
      registrarUrl:
          (root["registrar-url"] is String) ? root["registrar-url"] : null,
      apiKey: null,
    ));
  }

  if (Constants.rootDomainsIsEmpty()) {
    String error = "No registered root domains for the app.";
    // ignore: avoid_print
    print(error);
    throw error;
  }

  return results;
}
