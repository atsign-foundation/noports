import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';

void main() {
  group('NavigationRailController', () {
    final controller = NavigationRailController();
    // container.read(controller.notifier);

    test('getRoute 0 is home route', () {
      expect(controller.getRoute(0), AppRoute.home);
    });
    test('indexOf home route is 0', () {
      expect(controller.indexOf(AppRoute.home), 0);
    });

    test('isCurrentIndex home route return true', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.listen(navigationRailController, (_, __) {}, fireImmediately: true);
      final controller = container.read(navigationRailController.notifier);

      expect(controller.isCurrentIndex(AppRoute.home), true);
    });
    test(' getCurrentIndex return 0', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.listen(navigationRailController, (_, __) {}, fireImmediately: true);
      final controller = container.read(navigationRailController.notifier);

      expect(controller.getCurrentIndex(), 0);
    });
    test('getCurrentRoute is home route', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.listen(navigationRailController, (_, __) {}, fireImmediately: true);
      final controller = container.read(navigationRailController.notifier);

      expect(controller.getCurrentRoute(), AppRoute.home);
    });
    test('setIndex success', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.listen(navigationRailController, (_, __) {}, fireImmediately: true);
      final controller = container.read(navigationRailController.notifier);

      expect(controller.setIndex(1), true);
      expect(controller.setIndex(3), false);
      expect(controller.state, AppRoute.terminal);
    });
    test('setRoute success', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.listen(navigationRailController, (_, __) {}, fireImmediately: true);
      final controller = container.read(navigationRailController.notifier);

      expect(controller.setRoute(AppRoute.terminal), true);
      expect(controller.setRoute(AppRoute.onboarding), false);
      expect(controller.state, AppRoute.terminal);
    });
  });
}
