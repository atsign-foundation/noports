import 'package:chalkdart/chalk.dart';
import 'package:noports_core/src/commands/issue_keys/issue_keys_parser.dart';

class UsageMessages {
  static final mainMenu =
      '''
  
${chalk.bold('Usage:')} noports ${chalk.cyan('<command>')} [options]

${chalk.bold('Commands:')}
  ${chalk.cyan('activate')}      Activate your atsign (new user onboarding)
  ${chalk.cyan('issue-keys')}    Create a new enrollment
 
${chalk.bold('Examples:')}
  ${chalk.cyan('activate')}      noports activate '@alice:enroll:otp:123456' --keyfile ~/.mykeys.json
  ${chalk.cyan('issue-keys')}    noports issue-keys -a @alice -k /home/user/keys/@alice.atKeys
  
Run 'noports ${chalk.cyan('<command>')} --help' for more information
''';

  static final activateHelp =
      '''
${chalk.bold('Usage:')} noports activate ${chalk.cyan('<activation_string>')} [options]

${chalk.bold('Options:')}
  -k, --keyfile <path>        Path to save atKeys file
  -h, --help                  Show this help message

${chalk.bold('Examples:')}
  ${chalk.dim('# Using system-generated activation string')}
  noports activate '@alice:enroll:otp:123456'

  ${chalk.dim('# With custom keyfile location')}
  noports activate '@alice:enroll:otp:123456' --keyfile ~/.mykeys.json

${chalk.bold('Workflow:')}
  1. Run 'noports issue-keys @alice' on authenticated device
  2. Copy activation string to new device
  3. Run 'noports activate <string>' on new device
  4. Enrollment auto-approved

${chalk.bold('Notes:')}
  • If keys file exists at target location, you'll be prompted for alternate path
  • Default keyfile location: ~/.atsign/keys/@<atsign>_key.atKeys
  • activation_string needs to be wrapped in quotes
''';

  static final issueKeysHelp =
      '''
${chalk.bold('Usage:')} noports issue-keys -a ${chalk.cyan('<@atsign>')} ${chalk.cyan('[options]')}

${chalk.bold('Available Options: ')}
${IssueKeysParams.argParser.usage}

${chalk.bold('Example:')}
  noports issue-keys @alice
  noports issue-keys -a @alice -k /home/user/keys/@alice.atKeys
  noports issue-keys -a @alice -k /home/user/keys/@alice.atKeys -d dev01
  
${chalk.bold('Description:')}
  Generates an enrollment OTP. Then constructs the activation_string with available parameters. 
  Waits for and automatically approves matching enrollment request.

${chalk.bold('Workflow:')}
  1. Run 'noports issue-keys @alice' on authenticated device
  2. Copy activation string to new device
  3. Run 'noports activate <string>' on new device
  4. Enrollment auto-approved

${chalk.bold('Notes:')}
  • OTP expires in 1 hour
  • Resumable if interrupted (re-run the same command)
''';
}
