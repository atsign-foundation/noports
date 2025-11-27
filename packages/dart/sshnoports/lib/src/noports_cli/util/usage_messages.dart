import 'package:chalkdart/chalk.dart';

class UsageMessages {
  static final mainMenu = '''
  
${chalk.bold('Usage:')} noports ${chalk.cyan('<command>')} [options]

${chalk.bold('Commands:')}
  ${chalk.cyan('activate')}      Activate your atsign (new user onboarding)
  ${chalk.cyan('issue-keys')}    Create a new enrollment

Run 'noports ${chalk.cyan('<command>')} --help' for more information
''';

  static final activateHelp = '''
  
${chalk.bold('Usage:')} noports activate ${chalk.cyan('<activation_string>')}

${chalk.bold('Activation Methods:')}
  CRAM:       ${chalk.gray('@alice:cram:<secret>')}
  Enrollment: ${chalk.gray('@alice:enroll:otp:<code>[:name:<device>:keyfile:<path>]')}

${chalk.bold('Examples:')}
  noports activate '@alice:cram:a1b2c3d4e5f6'
  noports activate '@alice:enroll:otp:XYZ789'
  noports activate '@alice:enroll:otp:XYZ789:name:laptop:keyfile:~/.atsign/keys'

${chalk.bold('Notes:')}
  • Activation String can be generated using the issue-keys command
  • CRAM provides full account access
  • Enrollment requires approval from authenticated device (see: issue-keys)
''';

  static final issueKeysHelp = '''
  
${chalk.bold('Usage:')} noports issue-keys ${chalk.cyan('<@atsign>')}

${chalk.bold('Description:')}
  Generates an enrollment OTP constructs the activation_string with available parameters. 
  Waits for and automatically approves matching enrollment request.

${chalk.bold('Workflow:')}
  1. Run 'noports issue-keys @alice' on authenticated device
  2. Copy activation string to new device
  3. Run 'noports activate <string>' on new device
  4. Enrollment auto-approved

${chalk.bold('Example:')}
  noports issue-keys @alice

${chalk.bold('Notes:')}
  • OTP expires in 1 hour
  • Resumable if interrupted
''';
}
