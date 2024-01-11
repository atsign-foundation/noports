import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';

void main() {
  group('NavigationRailController', () {
    late NavigationRailController controller;
    late ProviderContainer container;
    setUp(() {
      controller = NavigationRailController();
      container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.listen(navigationRailController, (_, __) {}, fireImmediately: true);
      controller = container.read(navigationRailController.notifier);
    });

    test('''
    Given 0
    When getRoute is called
    Then return AppRoute.home
    ''', () {
      expect(controller.getRoute(0), AppRoute.home);
    });
    test('''
    Given AppRoute.home 
    When indexOf is called
    Then return 0
    ''', () {
      expect(controller.indexOf(AppRoute.home), 0);
    });

    test('''
    Given AppRoute 
    When isCurrentIndex is called
    Then return true
    And AppRoute.terminal is false
    ''', () {
      expect(controller.isCurrentIndex(AppRoute.home), true);
      expect(controller.isCurrentIndex(AppRoute.terminal), false);
    });
    test(''' 
    Given Default index as 0 
    When getCurrentIndex is called
    Then return 0
    And index is not 1
    ''', () {
      expect(controller.getCurrentIndex(), 0);
      expect(controller.getCurrentIndex(), isNot(1));
    });
    test('''
    Given AppRoute.home is the default route
    When getCurrentRoute is called
    Then return AppRoute.home
    and AppRoute.terminal is not the default route
    ''', () {
      expect(controller.getCurrentRoute(), AppRoute.home);
      expect(controller.getCurrentRoute(), isNot(AppRoute.terminal));
    });
    test('''
    Given 1 
    When setIndex is called
    Then return true
    And state is AppRoute.terminal
    And 3 is false
    ''', () {
      expect(controller.setIndex(1), true);
      expect(controller.setIndex(3), false);
      expect(controller.state, AppRoute.terminal);
    });
    test('''
    Given AppRoute.terminal 
    When setRoute is called 
    Then return true
    And AppRoute.onboarding is false
    And state is AppRoute.terminal
    ''', () {
      expect(controller.setRoute(AppRoute.terminal), true);
      expect(controller.setRoute(AppRoute.onboarding), false);
      expect(controller.state, AppRoute.terminal);
    });
  });
}
