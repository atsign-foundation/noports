import 'dart:convert';
import 'dart:io';

import 'package:npt_flutter/app.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AtsignInformation extends Loggable {
  final Atsign atsign;
  final String rootDomain;

  const AtsignInformation({required this.atsign, required this.rootDomain});

  Map<String, dynamic> toJson() => {
    "atsign": atsign,
    "root-domain": rootDomain,
  };

  static AtsignInformation? fromJson(Map json) {
    if (json["atsign"] is! String || json["root-domain"] is! String) {
      return null;
    }
    return AtsignInformation(
      atsign: json["atsign"],
      rootDomain: json["root-domain"],
    );
  }

  @override
  List<Object?> get props => [atsign, rootDomain];

  @override
  String toString() {
    return 'AtsignInformation($atsign, $rootDomain)';
  }
}

// This will return a map which looks like:
//
// {
//   "@alice": AtsignInformation{ atsign: "@alice", rootDomain: "root.atsign.org" },
//   "@bob": AtsignInformation{ atsign: "@alice", rootDomain: "vip.ve.atsign.zone" },
// }
//
// Note: AtsignInformation is a class, so usage will look like
//
// var atsign = "@alice";
// var atsignInfo = await getAtsignEntries();
// var rootDomain = atsignInfo[atsign].rootDomain;
//
// Now you have the rootDomain for the existing atsign and can use it to onboard
// correctly

Future<Map<String, AtsignInformation>> getAtsignEntries() async {
  var keychainAtsigns = await KeychainUtil.getAtsignList() ?? [];
  var atsignInfo = <AtsignInformation>[];
  try {
    atsignInfo = await _getAtsignInformationFromFile();
  } catch (e) {
    App.log(
      "Failed get Atsign Information, ignoring invalid file: ${e.toString()}"
          .loggable,
    );
    return {};
  }
  var atsignMap = <String, AtsignInformation>{};
  for (var item in atsignInfo) {
    if (keychainAtsigns.contains(item.atsign)) {
      atsignMap[item.atsign] = item;
    }
  }
  return atsignMap;
}

// This class will allow you to store atsign information
// you need to call this after onboarding a NEW atsign
Future<bool> saveAtsignInformation(AtsignInformation info) async {
  var f = await _getAtsignInformationFile();
  final List<AtsignInformation> atsignInfo;
  try {
    atsignInfo = await _getAtsignInformationFromFile(f);
  } catch (e) {
    // We only end up here if we failed to create, get, or read the file
    // we don't want to overwrite it in that scenario, so return false
    //
    // We won't end up here if it was a json parse error, such as invalid
    // json, we do want to overwrite that so that the app can recover as best
    // as possible
    return false;
  }
  if (f == null) return false;

  // Replace the existing entry with the new one if it exists
  bool found = false;
  for (int i = 0; i < atsignInfo.length; i++) {
    if (atsignInfo[i].atsign == info.atsign) {
      found = true;
      atsignInfo[i] = info;
    }
  }
  // Otherwise add it as a new entry
  if (!found) {
    atsignInfo.add(info);
  }
  try {
    f.writeAsString(
      jsonEncode(atsignInfo.map((e) => e.toJson()).toList()),
      mode: FileMode.writeOnly,
      flush: true,
    );
    return true;
  } catch (e) {
    App.log(
      "Failed to write Atsign Information to file: ${e.toString()}".loggable,
    );
    return false;
  }
}

// Does not throw, returns null if it can't get / create the file
Future<File?> _getAtsignInformationFile() async {
  final Directory dir;
  try {
    dir = await getApplicationSupportDirectory();
    dir.create(recursive: true); // This checks if it exists internally
  } catch (e) {
    App.log(
      "Failed to Get Application Support Directory: ${e.toString()}".loggable,
    );
    return null;
  }
  final f = File(p.join(dir.path, "atsign_information.json"));
  try {
    if (!await f.exists()) {
      f.create(recursive: true);
    }
    return f;
  } catch (e) {
    App.log("Failed to Get Atsign Information File : ${e.toString()}".loggable);
    return null;
  }
}

Future<List<AtsignInformation>> _getAtsignInformationFromFile([File? f]) async {
  f ??= await _getAtsignInformationFile();
  if (f == null) throw Exception("Failed to get the Atsign Information File");
  try {
    var contents = await f.readAsString();
    if (contents.trim().isEmpty) return [];
    var json = jsonDecode(contents);
    if (json is! Iterable) {
      return []; // The file format is invalid so return as a non-error and we will overwrite it
    }
    var res = <AtsignInformation>[];
    for (var item in json) {
      if (item is! Map) continue;
      var info = AtsignInformation.fromJson(item);
      if (info == null) continue;
      res.add(info);
    }
    return res;
  } catch (e) {
    App.log(
      "Failed to Parse Atsign Information File : ${e.toString()}".loggable,
    );
    rethrow;
  }
}
