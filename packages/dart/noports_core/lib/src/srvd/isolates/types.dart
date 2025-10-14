import 'dart:isolate';

typedef PortPairIsolateParams = (
  SendPort,
  bool, // logTraffic
  bool, // verbose
  String, // loggingTag
);
typedef SinglePortIsolateParams = (
  SendPort,
  bool, // logTraffic
  bool, // verbose
  String, // loggingTag
  String, // address
  bool, // use TLS
  int, // port to bind to
);
typedef PortPair = (int, int);

const int isolateStartTimeoutMs = 500;
const int isolateBindPortsTimeoutMs = 1500;

/// Wrapper for inter-isolate requests
class IIRequest {
  final int id;
  final String type;
  final dynamic payload;

  IIRequest({required this.id, required this.type, required this.payload});

  factory IIRequest.create(String type, dynamic payload) => IIRequest(
        id: DateTime.now().microsecondsSinceEpoch,
        type: type,
        payload: payload,
      );

  @override
  String toString() {
    return 'IIRequest{id: $id, type: $type, payload: $payload}';
  }
}

/// Wrapper for responses to inter-isolate requests
class IIResponse {
  final int id;
  final bool isError;
  final dynamic payload;

  IIResponse({required this.id, required this.isError, required this.payload});

  @override
  String toString() {
    return 'IIResponse{id: $id, isError: $isError, payload: $payload}';
  }
}
