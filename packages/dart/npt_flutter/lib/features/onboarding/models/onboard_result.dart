import 'package:at_client_flutter/at_client_flutter.dart';

sealed class OnboardResult {}

class OnboardSuccess extends OnboardResult {
  final Atsign atsign;
  final String? enrollmentId;
  OnboardSuccess(this.atsign, {this.enrollmentId});
}

class OnboardCancelled extends OnboardResult {}

class OnboardError extends OnboardResult {
  final String message;
  OnboardError(this.message);
}
