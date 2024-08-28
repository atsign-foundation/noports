import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:at_client/at_client.dart';
import 'package:noports_core/admin.dart';

policy(Alfred app, String pathPrefix, PolicyService api) {
  // all users TODO add query parameters for search, pagination etc
  app.get('$pathPrefix/user', (req, res) async {
    stderr.writeln('Fetching all users');
    final r = jsonEncode(await api.getUsers());
    stderr.writeln('Fetched all users');
    return r;
  });

  // get individual user - {"atSign":"@alice","name":"Joe Smith"}
  app.get('$pathPrefix/user/:atsign', (req, res) async {
    final atSign = Uri.decodeFull(req.uri.toString()).split('/').last;
    stderr.writeln('Fetching user $atSign');
    final r = jsonEncode(await api.getUser(atSign));
    stderr.writeln('Fetched user $atSign');
    return r;
  });

  // add or update a user
  app.post('$pathPrefix/user/:atsign', (req, res) async {
    final atSign = Uri.decodeFull(req.uri.toString()).split('/').last;
    stderr.writeln('Updating user $atSign');
    User u;
    try {
      u = User.fromJson((await req.body)! as Map<String, dynamic>);
    } catch (_) {
      throw IllegalArgumentException('Unable to construct User from this json');
    }
    if (atSign != u.atSign) {
      throw IllegalArgumentException('Mis-matched atSign');
    }
    await api.updateUser(u);
    stderr.writeln('Updated user $atSign');
  });

  // delete a user
  app.delete('$pathPrefix/user/:atsign', (req, res) async {
    final atSign = Uri.decodeFull(req.uri.toString()).split('/').last;
    stderr.writeln('Deleting user $atSign');
    try {
      await api.deleteUser(atSign);
    } on Exception catch (e) {
      res.statusCode = 400;
      await res.send(e);
    }
    stderr.writeln('Deleted user $atSign');
  });

  // get groups that a user is a member of
  app.get('$pathPrefix/user/:atsign/groups', (req, res) async {
    final atSign = Uri.decodeFull(req.uri.toString()).split('/').last;
    stderr.writeln('Fetching groups for user $atSign');
    final r = jsonEncode(await api.getGroupsForUser(atSign));
    stderr.writeln('Fetched groups for user $atSign');
    return r;
  });

  // all groups TODO add query parameters for search, pagination etc
  app.get('$pathPrefix/group', (req, res) async {
    stderr.writeln('Fetching all groups');
    final r = jsonEncode(await api.getUserGroups());
    stderr.writeln('Fetched all groups');
    return r;
  });

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
  app.get('$pathPrefix/group/:name', (req, res) async {
    final n = req.params['name'].toString();
    stderr.writeln('Fetching group $n');
    final r = jsonEncode(await api.getUserGroup(n));
    stderr.writeln('Fetched group $n');
    return r;
  });

  app.printRoutes();
}
