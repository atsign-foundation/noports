import 'dart:async';
import 'dart:convert';
import 'package:noports_core/sshnpa.dart';
import 'package:sshnoports/sshnpa_bootstrapper.dart' as bootstrapper;
import 'package:http/http.dart' as http;
import 'package:at_utils/at_logger.dart';

void main(List<String> args) async {
  await bootstrapper.run(DemoPagerDutyHandler(), args);
}

const JsonEncoder jsonPrettyPrinter = JsonEncoder.withIndent('    ');
final whitespace = RegExp(r'\s');
final logger = AtSignLogger(' Authorizer_PagerDuty_Demo');

/// - get the current oncalls list
/// - for each oncall item
///   - GET the escalation_policy from ${oncallItem['escalation_policy']['self']}
///   - check if escalation policy details match auth check request daemon details
/// - If matched escalation policy
///   - GET user info from ${oncallItem['user']['self']}
///
class DemoPagerDutyHandler implements SSHNPARequestHandler {
  @override
  Future<SSHNPAAuthCheckResponse> doAuthCheck(
      SSHNPAAuthCheckRequest authCheckRequest) async {
    final matchedEscalationPolicies = [];
    final matchedAtsigns = [];

    final oncalls = await pdGet('https://api.pagerduty.com/oncalls', 'oncalls') as List;
    for (final oncall in oncalls) {
      if (oncall['escalation_policy'] != null
      && oncall['user'] != null)  {
        final ep = await pdGet(oncall['escalation_policy']['self'], 'escalation_policy');
        bool matched = await _pdEscalationPolicyMatchesSSHNPDaemonInfo(ep, authCheckRequest);
        if (matched) {
          matchedEscalationPolicies.add(ep);
          final user = await pdGet(oncall['user']['self'], 'user');
          bool userMatched = await _pdUserMatchesSSHNPClientAtsign(user, authCheckRequest);
          if (userMatched) {
            matchedAtsigns.add(authCheckRequest.clientAtsign);
          }
        }
      }
    }

    if (matchedEscalationPolicies.isEmpty) {
      return SSHNPAAuthCheckResponse(authorized: false, message: 'No oncall escalation policy match found for'
          ' daemonAtsign ${authCheckRequest.daemonAtsign}'
          ' deviceGroupName ${authCheckRequest.daemonDeviceGroupName}'
          ' deviceName ${authCheckRequest.daemonDeviceName}');
    } else {
      if (! matchedAtsigns.contains(authCheckRequest.clientAtsign)) {
        return SSHNPAAuthCheckResponse(
            authorized: false, message: 'Found escalation policy match(es) for'
            ' daemonAtsign ${authCheckRequest.daemonAtsign}'
            ' deviceGroupName ${authCheckRequest.daemonDeviceGroupName}'
            ' deviceName ${authCheckRequest.daemonDeviceName}'
            ' but no on-caller with atSign ${authCheckRequest.clientAtsign}');
      } else {
        return SSHNPAAuthCheckResponse(authorized: true, message: 'Found on-caller '
            ' with atSign ${authCheckRequest.clientAtsign}'
            ' for daemonAtsign ${authCheckRequest.daemonAtsign}'
            ' and deviceGroupName ${authCheckRequest.daemonDeviceGroupName}'
            ' and deviceName ${authCheckRequest.daemonDeviceName}'
        );
      }
    }
  }

  Future<dynamic> pdGet (String uri, String field) async {
    logger.info('Sending HTTP GET request to $uri');
    var response = await http.get(
        Uri.parse(uri),
        headers: {
          "Accept": "application/json",
          "Authorization": "Token token=u+fPQ39jzh3UcsWKxQGA",
          "Content-Type": "application/json",
        });
    logger.info('Response received; decoding and extracting field $field');
    return jsonDecode(response.body)[field];
  }

  /// - get sshnp metadata from description
  /// - match on daemon (daemonAtsign) and deviceGroupName OR deviceName
  Future<bool> _pdEscalationPolicyMatchesSSHNPDaemonInfo(ep, SSHNPAAuthCheckRequest authCheckRequest) async {
    bool matched = false;
    // Split the description by whitespace
    final epDescriptionFragments = (ep['description'] ?? '').toString().split(whitespace);
    for (final descFrag in epDescriptionFragments) {
      // We're looking for fragments which start with sshnp:
      if (descFrag.toLowerCase().startsWith('sshnp:')) {
        // The format we're expecting is
        // sshnp:daemon:$daemonAtsign:deviceGroups:foo[,bar,...]:devices:foo[,bar,...]
        final mdFrags = descFrag.toString().split(':');
        String? epDaemonAtsign;
        List<String> epDeviceGroups = [];
        List<String> epDevices = [];
        final it = mdFrags.iterator;
        it.moveNext();
        while (it.moveNext()) {
          final mdFrag = it.current;
          switch (mdFrag) {
            case 'daemon' :
              if (it.moveNext()) {
                epDaemonAtsign = it.current;
              }
              break;
            case 'deviceGroups' :
              if (it.moveNext()) {
                epDeviceGroups = it.current.split(',');
              }
              break;
            case 'devices' :
              if (it.moveNext()) {
                epDevices = it.current.split(',');
              }
          }
        }
        /// - match on daemon (daemonAtsign) AND (deviceGroupName OR deviceName)
        if (epDaemonAtsign == authCheckRequest.daemonAtsign
            && (epDeviceGroups.contains(authCheckRequest.daemonDeviceGroupName)
                || epDevices.contains(authCheckRequest.daemonDeviceName))) {
          matched = true;
        }
      }
    }
    return matched;
  }

  ///   - get atsign metadata from description
  ///   - match on atsign (clientAtsign)
  Future<bool> _pdUserMatchesSSHNPClientAtsign(user, SSHNPAAuthCheckRequest authCheckRequest) async {
    // split the description by whitespace
    final userDescriptionFragments = (user['description'] ?? '').toString().split(whitespace);
    for (final descFrag in userDescriptionFragments) {
      // We're looking for fragments which start with atsign:
      if (descFrag.toLowerCase().startsWith('atsign:')) {
        // The format we're expecting is
        // atsign:@alice
        final mdFrags = descFrag.toString().split(':');
        final it = mdFrags.iterator;
        it.moveNext();
        if (it.moveNext()) {
          final usersAtsign = it.current;
          if (usersAtsign == authCheckRequest.clientAtsign) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
