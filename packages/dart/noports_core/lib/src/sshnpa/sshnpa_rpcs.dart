import 'dart:convert';

const JsonEncoder jsonPrettyPrinter = JsonEncoder.withIndent('    ');

class SSHNPAAuthCheckRequest {
  final String daemonAtsign;
  final String daemonDeviceName;
  final String daemonDeviceGroupName;
  final String clientAtsign;

  SSHNPAAuthCheckRequest({
    required this.daemonAtsign,
    required this.daemonDeviceName,
    required this.daemonDeviceGroupName,
    required this.clientAtsign,
  });

  static SSHNPAAuthCheckRequest fromJson(Map<String, dynamic> json) {
    return SSHNPAAuthCheckRequest(
      daemonAtsign: json['daemonAtsign'],
      daemonDeviceName: json['daemonDeviceName'],
      daemonDeviceGroupName: json['daemonDeviceGroupName'],
      clientAtsign: json['clientAtsign'],
    );
  }

  Map<String, dynamic> toJson() => {
        'daemonAtsign': daemonAtsign,
        'daemonDeviceName': daemonDeviceName,
        'daemonDeviceGroupName': daemonDeviceGroupName,
        'clientAtsign': clientAtsign,
      };

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}

class SSHNPAAuthCheckResponse {
  final bool authorized;
  final String? message;

  SSHNPAAuthCheckResponse({required this.authorized, required this.message});

  static SSHNPAAuthCheckResponse fromJson(Map<String, dynamic> json) {
    return SSHNPAAuthCheckResponse(
      authorized: json['authorized'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() =>
      {'authorized': authorized, 'message': message};

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}
