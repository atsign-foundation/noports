import 'package:chalkdart/chalk.dart';
import 'package:noports_core/src/commands/activate/activate_params.dart';
import 'package:noports_core/src/commands/issue_keys/issue_keys_params.dart';

class UsageMessages {
  static final mainMenu =
      '''
${chalk.bold('Usage')}
  noports issue-keys ${chalk.bold('@<atsign>')} ${chalk.gray('[options]')}
  noports activate ${chalk.bold('<activation_string>')} ${chalk.gray('[options]')}

${chalk.bold('Examples')}
  noports activate '@alice:cram:secret123' (one-time onboarding)

  noports issue-keys -a @alice
  noports issue-keys -a @alice --key-file /path/to/@alice.atKeys --device laptop01
  
  noports activate '@alice:enroll:otp:123456'
  noports activate '@alice:enroll:otp:123456' --target-keyfile /Users/alice/keys/.mykeys.json

${chalk.bold('Further help')}
  noports ${chalk.cyan('<command>')} --help
''';

  static final activateHelp =
      '''
${chalk.bold('Usage:')} noports activate ${chalk.cyan('<activation_string>')} [options]

  Performs CRAM Onboarding for an atsign (or) initiates a new device enrollment
  
    Options:

\t${ActivateParams.argParser.usage.split('\n').map((line) => '  $line').join('\n\t')}

${chalk.bold('Notes')}
  • activation_string is system-generated (run 'noports issue-keys --help')
  • Default keyfile: ~/.atsign/keys/@<atsign>_key.atKeys
''';

  static final issueKeysHelp =
      '''
${chalk.bold('Usage:')} noports issue-keys ${chalk.cyan('@<atsign>')} [options]

  Generates an activation string and auto-approves the corresponding enrollment.
  
    Options:
  
\t${IssueKeysParams.argParser.usage.split('\n').map((line) => '  $line').join('\n\t')}

${chalk.bold('Workflow')}
  1. Run 'noports issue-keys -a @alice' on authenticated device
  2. Copy displayed activation_string
  3. Run 'noports activate <activation_string>' on new device
  4. Enrollment automatically approved

${chalk.bold('Notes')}
  • The activation_string is valid for 1 hour
  • Resumable if interrupted (re-run same command)
  • Device name argument applies the target device, not the executing device.
''';
}
