import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:test/test.dart';

void main() {
  group(
    'TerminalSessionController',
    () {
      late ProviderContainer container;
      late TerminalSessionController controller;
      setUp(() {
        container = ProviderContainer();
        addTearDown(() => container.dispose());

        container.listen(terminalSessionController.notifier, (_, __) {}, fireImmediately: true);
        controller = container.read(terminalSessionController.notifier);
      });
      test(
        'createSession',
        () {
          expect(controller.createSession(), isA<String>());
        },
      );
      test(
        'setSession',
        () {
          controller.setSession('test');
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

        container.listen(terminalSessionFamilyController('test').notifier, (_, __) {}, fireImmediately: true);
        controller = container.read(terminalSessionFamilyController('test').notifier);
      });

      test(
        'issueDisplayName success',
        () {
          controller.issueDisplayName('TestProfile');
          expect(controller.state.displayName, 'TestProfile-1');
          controller.issueDisplayName('TestProfile');
          expect(controller.state.displayName, 'TestProfile-2');
          expect(controller.displayName, 'TestProfile-2');
        },
      );
      test(
        'setProcess success',
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
