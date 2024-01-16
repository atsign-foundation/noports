import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_flutter/src/controllers/terminal_session_controller.dart';

void main() {
  group(
    'TerminalSessionController',
    () {
      late ProviderContainer container;
      late TerminalSessionController controller;
      setUp(() {
        container = ProviderContainer();
        addTearDown(() => container.dispose());

        container.listen(terminalSessionController.notifier, (_, __) {},
            fireImmediately: true);
        controller = container.read(terminalSessionController.notifier);
      });
      test(
        '''
      Given no argument
      When createSession is called
      Then return a String
      ''',
        () {
          expect(controller.createSession(), isA<String>());
        },
      );
      test(
        '''
      Given test
      When setSession is called
      Then state is test
      And state is not exam
      ''',
        () {
          controller.setSession('test');
          expect(controller.state, 'test');
          expect(controller.state, isNot('exam'));
        },
      );
    },
  );
  group(
    'TerminalSessionFamilyController',
    () {
      late ProviderContainer container;
      late TerminalSessionFamilyController controller;
      setUp(() {
        container = ProviderContainer();
        addTearDown(() => container.dispose());

        container.listen(
            terminalSessionFamilyController('test').notifier, (_, __) {},
            fireImmediately: true);
        controller =
            container.read(terminalSessionFamilyController('test').notifier);
      });

      test(
        '''
      Given TestProfile
      When issueDisplayName is called the first time
      Then state.displayName is TestProfile-1
      When issueDisplayName is called the second time
      Then state.displayName is TestProfile-2
      And displayName is TestProfile-2
      ''',
        () {
          controller.issueDisplayName('TestProfile');
          expect(controller.state.displayName, 'TestProfile-1');
          controller.issueDisplayName('TestProfile');
          expect(controller.state.displayName, 'TestProfile-2');
          expect(controller.displayName, 'TestProfile-2');
        },
      );
      test(
        '''
      Given no arguments
      When setProcess is called
      Then state.command is null
      And stat.args is empty list
      When setProcess is called with arguments
      Then state.command is test
      And state.args is a list with test
      ''',
        () {
          controller.setProcess();
          expect(controller.state.command, null);
          expect(controller.state.args, []);
          controller.setProcess(command: 'test', args: ['test']);
          expect(controller.state.command, 'test');
          expect(controller.state.args, ['test']);
        },
      );
    },
  );
}
