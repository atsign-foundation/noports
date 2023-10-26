class SSHNPAAuthCheckRequest {
  final String daemonAtsign;
  final String daemonDeviceName;
  final String clientAtsign;

  SSHNPAAuthCheckRequest({
    required this.daemonAtsign,
    required this.daemonDeviceName,
    required this.clientAtsign,
  });

  static SSHNPAAuthCheckRequest fromJson(Map<String, dynamic> json) {
    return SSHNPAAuthCheckRequest(
      daemonAtsign: json['daemonAtsign'],
      daemonDeviceName: json['daemonDeviceName'],
      clientAtsign: json['clientAtsign'],
    );
  }

  Map<String, dynamic> toJson() =>
      {
        'daemonAtsign': daemonAtsign,
        'daemonDeviceName': daemonDeviceName,
        'clientAtsign': clientAtsign,
      };
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
      {
        'authorized': authorized,
        'message': message
      };
}
