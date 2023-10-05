import 'dart:async';

import 'package:at_app_flutter/at_app_flutter.dart';
import 'package:at_contact/at_contact.dart';
import 'package:at_contacts_flutter/services/contact_service.dart';
import 'package:at_contacts_flutter/utils/init_contacts_service.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_utils/at_logger.dart' show AtSignLogger;
import 'package:at_utils/at_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/utils.dart' show DefaultArgs;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/repository/navigation_repository.dart';

/// A provider that exposes an [AuthenticationRepository] instance to the app.
final authenticationRepositoryProvider = Provider<AuthenticationRepository>((ref) => AuthenticationRepository());

/// A singleton that makes all the network calls to the @platform.
class AuthenticationRepository {
  AuthenticationRepository();

  final AtSignLogger _logger = AtSignLogger(AtEnv.appNamespace);

  AtClient? atClient;
  AtClientService? atClientService;
  var atClientManager = AtClientManager.getInstance();
  static var atContactService = ContactService();

  /// This function will clear the keychain if the app installed newly again.
  Future<void> checkFirstRun() async {
    _logger.finer('Checking for keychain entries to clear');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('first_run') ?? true) {
      _logger.finer('First run detected. Clearing keychain');
      await clearKeychainEntries();
      await prefs.setBool('first_run', false);
    }
  }

  Future<void> clearKeychainEntries() async {
    List<String> atsignList = await KeyChainManager.getInstance().getAtSignListFromKeychain();
    if (atsignList.isEmpty) {
      return;
    } else {
      await Future.forEach(atsignList, (String atsign) async {
        await KeyChainManager.getInstance().resetAtSignFromKeychain(atsign);
      });
    }
  }

  Future<AtClientPreference> loadAtClientPreference() async {
    var dir = await getApplicationSupportDirectory();

    return AtClientPreference()
      ..rootDomain = AtEnv.rootDomain
      ..namespace = DefaultArgs.namespace
      ..hiveStoragePath = dir.path
      ..commitLogPath = dir.path
      ..isLocalStoreRequired = true;
  }

  /// Signs user into the @platform.
  void handleSwitchAtsign(String? atsign) async {
    final result = await AtOnboarding.onboard(
      context: NavigationRepository.navKey.currentContext!,
      isSwitchingAtsign: true,
      atsign: atsign,
      config: AtOnboardingConfig(
        atClientPreference: await loadAtClientPreference(),
        domain: AtEnv.rootDomain,
        rootEnvironment: AtEnv.rootEnvironment,
        appAPIKey: AtEnv.appApiKey,
      ),
    );
    switch (result.status) {
      case AtOnboardingResultStatus.success:
        _logger.finer('Successfully onboarded ${result.atsign}');
        // DudeService.getInstance().monitorNotifications(NavigationService.navKey.currentContext!);
        // AtClientManager.getInstance().atClient.syncService.addProgressListener(MySyncProgressListener());
        initializeContactsService(rootDomain: AtEnv.rootDomain);
        final context = NavigationRepository.navKey.currentContext!;
        if (context.mounted) {
          context.goNamed(AppRoute.home.name);
        }

        break;

      case AtOnboardingResultStatus.error:
        _logger.severe('Onboarding throws ${result.message} error');
        CustomSnackBar.error(content: result.message ?? '');
        break;

      case AtOnboardingResultStatus.cancel:
        break;
    }
    // Onboarding(
    //   atsign: atsign,
    //   context: NavigationService.navKey.currentContext!,
    //   atClientPreference: await loadAtClientPreference(),
    //   domain: AtEnv.rootDomain,
    //   rootEnvironment: AtEnv.rootEnvironment,
    //   appAPIKey: AtEnv.appApiKey,
    //   onboard: (value, atsign) async {
    //     DudeService.getInstance()
    //       ..atClientService = value[atsign]
    //       ..atClient = DudeService.getInstance()
    //           .atClientService!
    //           .atClientManager
    //           .atClient;

    //     _logger.finer('Successfully onboarded $atsign');
    //   },
    //   onError: (error) {
    //     _logger.severe('Onboarding throws $error error');
    //   },
    //   nextScreen: const SendDudeScreen(),
    // );
  }

  /// Get atsigns associated with the app.
  Future<List<String>?> getAtsignList() async {
    try {
      return KeychainUtil.getAtsignList();
    } on AtClientException catch (atClientExcep) {
      _logger.severe('❌ AtClientException : ${atClientExcep.message}');
      return [];
    } catch (e) {
      _logger.severe('❌ Exception : ${e.toString()}');
      return [];
    }
  }

  /// get atsign AtContact.
  Future<AtContact> getAtContact(String atSign) async {
    return await getAtSignDetails(atSign);
  }

  /// get current atsign.
  String? getCurrentAtSign() {
    return atClientManager.atClient.getCurrentAtSign();
  }

  /// get current atsign atcontact.
  Future<AtContact> getCurrentAtContact() async {
    var atSign = atClientManager.atClient.getCurrentAtSign();
    return await getAtSignDetails(atSign!);
  }
}
