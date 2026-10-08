// Extension to allow testing with custom parameters
import 'package:noports_core/commands.dart';

class IssueKeysTest extends IssueKeys {
  static const defaultEnrollmentCheckIntervalDuration = Duration(seconds: 1);
  static const defaultMaxRetries = 1;

  IssueKeysTest.test(
    super.params, {
    super.atClient,
    super.enrollmentService,
    int? maxRetries,
    Duration? checkInterval,
  }) : super(
         maxRetries: maxRetries ?? defaultMaxRetries,
         checkInterval: checkInterval ?? defaultEnrollmentCheckIntervalDuration,
       );

  @override
  Future<void> generateOTP() async {
    super.params.otp = '12345A';
  }
}
