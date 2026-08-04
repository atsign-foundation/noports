import 'package:at_client_flutter/at_client_flutter.dart';

enum NoPortsOnboardingResultStatus { success, error, cancel }

class NoPortsOnboardingResult {
  final NoPortsOnboardingResultStatus status;
  final Atsign? atsign;
  final String? message;

  const NoPortsOnboardingResult._({
    required this.status,
    this.atsign,
    this.message,
  });

  factory NoPortsOnboardingResult.success({required Atsign atsign}) =>
      NoPortsOnboardingResult._(
        status: NoPortsOnboardingResultStatus.success,
        atsign: atsign,
      );

  factory NoPortsOnboardingResult.error({required String message}) =>
      NoPortsOnboardingResult._(
        status: NoPortsOnboardingResultStatus.error,
        message: message,
      );

  factory NoPortsOnboardingResult.cancelled() => const NoPortsOnboardingResult._(
    status: NoPortsOnboardingResultStatus.cancel,
  );

  @override
  String toString() =>
      'NoPortsOnboardingResult($status, atsign: $atsign, message: $message)';
}
