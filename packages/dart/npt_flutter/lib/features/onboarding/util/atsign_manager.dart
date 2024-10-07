abstract class AtsignInformation {
  String get atSign;
  String get rootDomain;
}

// This will return a map which looks like:
//
// {
//   "@alice": AtsignInformation{ atSign: "@alice", rootDomain: "root.atsign.org" },
//   "@bob": AtsignInformation{ atSign: "@alice", rootDomain: "vip.ve.atsign.zone" },
// }
//
// Note: AtsignInformation is a class, so usage will look like
//
// var atSign = "@alice";
// var atSignInfo = await getAtsignEntries();
// var rootDomain = atSignInfo[atSign].rootDomain;
//
// Now you have the rootDomain for the existing atSign and can use it to onboard
// correctly

Future<Map<String, AtsignInformation>> getAtsignEntries() {
  return Future.value({});
}

// This class will allow you to store atSign information
// you need to call this after onboarding a NEW atSign
Future<bool> saveAtsignInformation(AtsignInformation info) {
  return Future.value(true);
}
