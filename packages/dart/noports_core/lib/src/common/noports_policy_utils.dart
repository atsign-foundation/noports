import 'package:at_policy/at_policy.dart';

enum NoPortsIntents {
  ping,
  sendSshPublicKey,
  permitOpen,
}

PolicyIntent intentPermitOpen(List<String> addresses) {
  return PolicyIntent(
      intent: NoPortsIntents.permitOpen.name, params: {'addresses': addresses});
}

PolicyInfo infoPermitOpen(List<String> addresses) {
  return PolicyInfo(intent: NoPortsIntents.permitOpen.name, info: {
    'addresses': ['*:*']
  });
}

PolicyIntent intentPing() {
  return PolicyIntent(intent: NoPortsIntents.ping.name, params: null);
}

PolicyInfo infoPing(bool authorized) {
  return PolicyInfo(
      intent: NoPortsIntents.ping.name, info: {'authorized': authorized});
}

PolicyIntent intentSendSshPublicKey() {
  return PolicyIntent(
      intent: NoPortsIntents.sendSshPublicKey.name, params: null);
}

PolicyInfo infoSendSshPublicKey(bool authorized) {
  return PolicyInfo(
      intent: NoPortsIntents.sendSshPublicKey.name,
      info: {'authorized': authorized});
}
