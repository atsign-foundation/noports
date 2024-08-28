import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:at_client/at_client.dart';
import 'package:noports_core/admin.dart';

policy(Alfred app, String pathPrefix, PolicyService api) {
  // all groups TODO add query parameters for search, pagination etc
  app.get('$pathPrefix/group', (req, res) async {
    stderr.writeln('Fetching all groups');
    final r = jsonEncode(await api.getUserGroups());
    stderr.writeln('Fetched all groups');
    return r;
  });

  // get by group ID
  app.get('$pathPrefix/group/:id', (req, res) async {
    final id = req.params['id'].toString();
    stderr.writeln('Fetching group $id');
    final g = await api.getUserGroup(id);
    if (g == null) {
      res.statusCode = 404;
      await res.send('No group with id $id');
      return jsonEncode({});
    }
    final r = jsonEncode(g);
    stderr.writeln('Fetched group $id (${g.name})');
    return r;
  });

  // create new group
  app.post('$pathPrefix/group', (req, res) async {
    stderr.writeln('Creating new group');
    UserGroup ug;
    try {
      ug = UserGroup.fromJson((await req.body)! as Map<String, dynamic>);
    } catch (_) {
      throw IllegalArgumentException('Unable to construct User from this json');
    }
    try {
      await api.createUserGroup(ug);
      stderr.writeln('Updated group ${ug.name}');
      return jsonEncode(ug);
    } catch (e) {
      res.statusCode = 400;
      await res.send(e.toString());
    }
  });

  // update group
  app.put('$pathPrefix/group/:id', (req, res) async {
    final id = req.params['id'].toString();
    stderr.writeln('Updating group with ID $id');

    UserGroup ug;
    try {
      ug = UserGroup.fromJson((await req.body)! as Map<String, dynamic>);
    } catch (_) {
      throw IllegalArgumentException('Unable to construct User from this json');
    }
    if (ug.id != id) {
      throw IllegalArgumentException('GroupID mis-match');
    }
    try {
      await api.updateUserGroup(ug);
      stderr.writeln('Updated group ${ug.name}');
      return jsonEncode(ug);
    } catch (e) {
      res.statusCode = 400;
      await res.send(e.toString());
    }
  });

  // delete group
  app.delete('$pathPrefix/group/:id', (req, res) async {
    final id = req.params['id'].toString();
    stderr.writeln('Updating group with ID $id');
    try {
      await api.deleteUserGroup(id);
    } catch (e) {
      res.statusCode = 400;
      await res.send(e.toString());
    }
  });

  app.printRoutes();
}
