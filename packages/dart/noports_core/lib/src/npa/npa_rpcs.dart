import 'dart:convert';

const JsonEncoder jsonPrettyPrinter = JsonEncoder.withIndent('    ');

class NPAAuthCheckRequest {
  final String daemonAtsign;
  final String daemonDeviceName;
  final String daemonDeviceGroupName;
  final String clientAtsign;

  NPAAuthCheckRequest({
    required this.daemonAtsign,
    required this.daemonDeviceName,
    required this.daemonDeviceGroupName,
    required this.clientAtsign,
  });

  static NPAAuthCheckRequest fromJson(Map<String, dynamic> json) {
    return NPAAuthCheckRequest(
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

class NPAAuthCheckResponse {
  final bool authorized;
  final String? message;

  NPAAuthCheckResponse({required this.authorized, required this.message});

  static NPAAuthCheckResponse fromJson(Map<String, dynamic> json) {
    return NPAAuthCheckResponse(
      authorized: json['authorized'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() =>
      {'authorized': authorized, 'message': message};

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}
