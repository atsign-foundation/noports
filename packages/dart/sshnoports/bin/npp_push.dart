import 'dart:convert';
import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:uuid/uuid.dart' as u;
import 'package:sshnoports/src/profile.dart';

import 'package:at_cli_commons/at_cli_commons.dart' as cli;

main(List<String> args) async {
  String myAtsign = '@baboonblue18';
  String userAtsign = '@garycasey';
  cli.CLIBase cliBase = cli.CLIBase(
      atSign: myAtsign,
      homeDir: cli.getHomeDirectory(),
      nameSpace: 'noports',
      rootDomain: 'root.atsign.org',
      verbose: true,
      syncDisabled: true);

  await cliBase.init();

  Profile profile = Profile(
    u.Uuid().v4(),
    displayName: args[0],
    sshnpdAtsign: '@asparagussquare',
    deviceName: 'some_device',
    relayAtsign: '@stream',
    remotePort: 8080,
    localPort: 0,
  );

  var profileKey = AtKey.fromString('$userAtsign'
      ':'
      '${profile.uuid}.profiles.noports'
      '$myAtsign');
  profileKey.metadata.ttr = -1; // cache indefinitely
  profileKey.metadata.ttl = 30000;

  print(profileKey);
  print(jsonEncode(profile.toJson()));

  print ('$myAtsign is CREATING $profileKey');
  await cliBase.atClient.put(profileKey, jsonEncode(profile.toJson()),
      putRequestOptions: PutRequestOptions()..useRemoteAtServer = true);

  print('\nWaiting for 20 seconds');
  await Future.delayed(Duration(seconds: 25));

  print ('$myAtsign is DELETING $profileKey');
  await cliBase.atClient.delete(profileKey,
      deleteRequestOptions: DeleteRequestOptions()..useRemoteAtServer = true);

  exit(0);
}
