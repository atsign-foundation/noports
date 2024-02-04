import 'dart:developer';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_flutter/src/utility/extensions/go_router_extensions.dart';

import '../controllers/config_controller.dart';
import '../controllers/navigation_controller.dart';
import '../repository/authentication_repository.dart';
import '../repository/navigation_repository.dart';

class MySyncProgressListener extends SyncProgressListener {
  final WidgetRef ref;

  MySyncProgressListener(this.ref);
  @override
  void onSyncProgressEvent(SyncProgress syncProgress) async {
    final context = NavigationRepository.navKey.currentContext!;
    final currentRoute = GoRouter.of(context).location;
    log(currentRoute);

    final isSyncStatusSuccess = syncProgress.syncStatus == SyncStatus.success;
    final isSyncStatusFailure = syncProgress.syncStatus == SyncStatus.failure;
    final isCurrentRouteHome = currentRoute == '/${AppRoute.home.name}';

    final isFirstRun = await AuthenticationRepository().checkFirstRun();

    if (isSyncStatusSuccess && isCurrentRouteHome && isFirstRun) {
      await ref.read(configListController.notifier).refresh();
      CustomSnackBar.notification(content: 'Sync Completed');
      await AuthenticationRepository().setFirstRun(false);
      log('Initial Sync completed');
    } else if (isSyncStatusFailure && isCurrentRouteHome && isFirstRun) {
      await ref.read(configListController.notifier).refresh();
      CustomSnackBar.notification(content: 'Sync failed... Retrying');

      log('Initial Sync failed');
    }
  }
}
