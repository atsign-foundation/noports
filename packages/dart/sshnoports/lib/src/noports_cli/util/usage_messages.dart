class UsageMessages {
  static final mainMenu = '''
  Usage: noports <command> <argument_string>
  
  Available Commands:
    activate      Initialize your @sign with Noports
    issue-keys    Generates an enroll command and auto-approves it for you 
  ''';

  static final activateMenu = '''Command: activate
    
  Available Subcommands:
    cram          Activate using CRAM authentication
    enroll        Generates an activation string and auto-approves the corresponding enrollment request
    
  Usage:
    noports activate <@atsign>:cram:<cram_secret>
    noports activate <@atsign>:enroll:otp:<otp>[:name:<device_name>:keyfile:<keyfile_path>]
''';

  static final issueKeys = '''
  Command: issue-keys
  
  Description:

  Generates a copy-pastable activation string, then listens for an enrollment request
  matching the appName and deviceName in that string, approving it as soon as it arrives.
  
  Usage:
    noports issue-keys <atsign>
  ''';
}
