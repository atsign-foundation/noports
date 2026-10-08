import 'dart:io';
import '../diagnostic_check.dart';

class ConnectivityCheck extends DiagnosticCheck {
  @override
  String get name => 'Connectivity Check';

  @override
  String get description => 'Checks internet access and AtSign root server reachability';

  @override
  Future<CheckResult> run(Map<String, dynamic> context) async {
    final start = DateTime.now();
    var messages = <String>[];
    bool allPassed = true;

    // 1. Internet Check (Google DNS)
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        messages.add('Internet Connection: OK');
      } else {
        messages.add('Internet Connection: FAILED (Lookup empty)');
        allPassed = false;
      }
    } catch (_) {
      messages.add('Internet Connection: FAILED (Lookup failed)');
      allPassed = false;
    }

    // 2. Root Server Check (root.atsign.org:64)
    try {
      final socket = await Socket.connect('root.atsign.org', 64, timeout: Duration(seconds: 5));
      messages.add('Root Server (root.atsign.org:64): REACHABLE');
      socket.destroy();
    } catch (e) {
      messages.add('Root Server (root.atsign.org:64): UNREACHABLE ($e)');
      allPassed = false;
    }

    return CheckResult(
      checkName: name,
      status: allPassed ? CheckStatus.pass : CheckStatus.fail,
      message: messages.join('\n      '),
      duration: DateTime.now().difference(start),
    );
  }
}
