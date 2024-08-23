import 'dart:convert';

import 'package:alfred/alfred.dart';
import 'package:at_client/at_client.dart';
import 'package:noports_core/admin.dart';

policy(Alfred app, String pathPrefix, PolicyService api) {
  // all users TODO add query parameters for search, pagination etc
  app.get('$pathPrefix/user', (req, res) async => jsonEncode(await api.getUsers()));

  // get individual user - {"atSign":"@alice","name":"Joe Smith"}
  app.get('/user/:atsign', (req, res) async {
    final atSign = Uri.decodeFull(req.uri.toString()).split('/').last;
    return jsonEncode(await api.getUser(atSign));
  });

  // add or update a user
  app.post('$pathPrefix/user', (req, res) async {
    User u;
    try {
      u = User.fromJson((await req.body)! as Map<String, dynamic>);
    } catch (_) {
      throw IllegalArgumentException('Unable to construct User from this json');
    }
    await api.updateUser(u);
  });

  // delete a user
  app.delete('$pathPrefix/user/:atsign', (req, res) async {
    final atSign = Uri.decodeFull(req.uri.toString()).split('/').last;
    await api.deleteUser(atSign);
  });

  // get groups that a user is a member of
  app.get('$pathPrefix/user/:atsign/groups', (req, res) async {
    final atSign = Uri.decodeFull(req.uri.toString()).split('/').last;
    return jsonEncode(await api.getGroupsForUser(atSign));
  });

  // all groups TODO add query parameters for search, pagination etc
  app.get('$pathPrefix/group', (req, res) async => jsonEncode(await api.getUserGroups()));

  // get individual group -
  // {"name":"sysadmins",
  //  "userAtSigns":["@alice", ...],
  //  "permissions":{
  //    "daemonAtSigns":["@bob", ...],
  //    "devices":{
  //      "name":"some_device_name",
  //      "permitOpens":["localhost:3000", ...]
  //    },
  //    "deviceGroups":{
  //      "name":"some_device_group_name",
  //      "permitOpens":["localhost:3000", ...]
  //    }
  //  }
  // }
  app.get(
      '$pathPrefix/group/:name',
      (req, res) async =>
          jsonEncode(await api.getUserGroup(req.params['name'].toString())));
}
