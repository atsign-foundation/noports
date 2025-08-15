import 'dart:developer';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_services.dart';
// ignore: implementation_imports
import 'package:at_onboarding_flutter/src/utils/at_onboarding_app_constants.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/util/post_onboard.dart';
import 'package:npt_flutter/features/onboarding/util/pre_offboard.dart';
import 'package:npt_flutter/features/onboarding/widgets/activate_atsign_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/apkam_choice_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_apkam_dialog.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_dialog.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/features/profile_list/widgets/connected_profiles_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/loading_page.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:npt_flutter/widgets/custom_card.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ManageAtSignPage extends StatefulWidget {
  const ManageAtSignPage({super.key});

  @override
  State<ManageAtSignPage> createState() => _ManageAtSignPageState();
}

class _ManageAtSignPageState extends State<ManageAtSignPage> {
  List<String>? availableAtSigns;
  String? currentAtSign;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAtSigns();
  }

  Future<void> _loadAtSigns() async {
    try {
      final atSignList = await KeychainUtil.getAtsignList();
      final current = context.read<OnboardingCubit>().getAtSign();
      
      setState(() {
        availableAtSigns = atSignList ?? [];
        currentAtSign = current;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        availableAtSigns = [];
        isLoading = false;
      });
      if (mounted) {
        CustomSnackBar.error(content: 'Failed to load atSigns: $e');
      }
    }
  }

  Future<void> _switchToAtSign(String atSign) async {
    // Check for connected profiles before switching
    if (context.read<ProfilesRunningCubit>().state.socketConnectors.keys.toSet().isNotEmpty) {
      final shouldContinue = await showDialog<bool>(
        barrierDismissible: false,
        context: context,
        builder: (context) => const ConnectedProfilesDialog(),
      );
      
      if (shouldContinue != true) return;
    }

    setState(() => isLoading = true);

    try {
      final currentContext = App.navState.currentContext!;
      final rootDomain = currentContext.read<OnboardingCubit>().getRootDomain();
      final atClientPreference = await AtClientMethods.loadAtClientPreference(rootDomain);
      
      await preSignout();
      final result = await AtOnboarding.changePrimaryAtsign(atsign: atSign);
      
      if (result) {
        final onboardingResult = await AtOnboarding.onboard(
          atsign: atSign,
          context: currentContext,
          config: AtOnboardingConfig(
            atClientPreference: atClientPreference,
            domain: rootDomain,
            rootEnvironment: RootEnvironment.Production,
            appAPIKey: await Constants.appAPIKey,
          ),
        );
        
        if (onboardingResult.status == AtOnboardingResultStatus.success) {
          await BackupKeyUtils().backupKeyStatusCheck();
          await postOnboard(atSign, rootDomain);
          await _loadAtSigns(); // Reload the atSigns list to reflect the change
          
          if (mounted) {
            CustomSnackBar.success(content: 'Switched to $atSign successfully');
          }
        } else {
          throw Exception('Onboarding failed');
        }
      } else {
        throw Exception('Failed to change primary atSign');
      }
    } catch (e) {
      log('Switch atSign error: $e');
      if (mounted) {
        CustomSnackBar.error(content: 'Failed to switch atSign: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteAtSign(String atSign) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete atSign'),
        content: Text('Are you sure you want to remove $atSign from this device?\n\nThis will only remove it from the local keychain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        setState(() => isLoading = true);
        await KeyChainManager.getInstance().deleteAtSignFromKeychain(atSign);
        await _loadAtSigns(); // Reload the list
        
        if (mounted) {
          CustomSnackBar.success(content: 'Removed $atSign from keychain');
        }
      } catch (e) {
        log('Delete atSign error: $e');
        if (mounted) {
          CustomSnackBar.error(content: 'Failed to remove atSign: $e');
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  Future<void> _addNewAtSign() async {
    try {
      setState(() => isLoading = true);
      
      // Get available atSigns from keychain (empty for new ones)
      var options = await getAtsignEntries();
      
      final cubit = context.read<OnboardingCubit>();
      // Set empty atSign to force user to enter a new one
      cubit.setState(atSign: "", rootDomain: cubit.state.rootDomain);
      
      // Show the onboarding dialog
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => OnboardingDialog(options: options),
      );
      
      if (shouldProceed != true) {
        setState(() => isLoading = false);
        return;
      }
      
      // Get the selected atSign and rootDomain from cubit
      var atsignInformation = cubit.state;
      String atsign = atsignInformation.atSign;
      String rootDomain = atsignInformation.rootDomain;
      
      if (atsign.isEmpty) {
        setState(() => isLoading = false);
        if (mounted) {
          CustomSnackBar.error(content: 'Please enter an atSign');
        }
        return;
      }
      
      // Use the same onboarding logic as the main onboarding flow
      await _performOnboarding(atsign: atsign, rootDomain: rootDomain);
      
    } catch (e) {
      log('Add new atSign error: $e');
      if (mounted) {
        CustomSnackBar.error(content: 'Failed to add new atSign: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _performOnboarding({required String atsign, required String rootDomain}) async {
    var atSigns = await KeyChainManager.getInstance().getAtSignListFromKeychain();
    var apiKey = await Constants.appAPIKey;
    var config = AtOnboardingConfig(
      atClientPreference: await AtClientMethods.loadAtClientPreference(rootDomain),
      rootEnvironment: RootEnvironment.Production,
      domain: rootDomain,
      appAPIKey: apiKey,
    );

    AtOnboardingResult? onboardingResult;

    if (atSigns.contains(atsign)) {
      // atSign already exists in keychain, just onboard
      onboardingResult = await AtOnboarding.onboard(
        atsign: atsign,
        context: context,
        config: config,
      );
    } else {
      // New atSign, need to handle activation/registration
      var util = NoPortsOnboardingUtil(config);
      onboardingResult = await _handleAtsignByStatus(atsign, util);
    }

    if (!mounted) return;
    
    switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
      case AtOnboardingResultStatus.success:
        await BackupKeyUtils().backupKeyStatusCheck();
        await postOnboard(onboardingResult!.atsign!, rootDomain);
        await _loadAtSigns(); // Reload the list
        
        if (mounted) {
          CustomSnackBar.success(content: 'Added ${onboardingResult.atsign} successfully');
        }
        break;
      case AtOnboardingResultStatus.error:
        if (mounted) {
          CustomSnackBar.error(content: onboardingResult?.message ?? 'Failed to add atSign');
        }
        break;
      case AtOnboardingResultStatus.cancel:
        // User cancelled, do nothing
        break;
    }
  }

  Future<AtOnboardingResult?> _handleAtsignByStatus(String atsign, NoPortsOnboardingUtil util) async {
    AtStatus status;
    final strings = AppLocalizations.of(context)!;

    try {
      status = await util.atServerStatus(atsign);
    } catch (_) {
      return AtOnboardingResult.error(
        message: strings.errorAtServerUnavailable,
      );
    }
    
    AtOnboardingResult? result;
    if (!mounted) return null;
    
    var initialStatus = status.status();
    switch (initialStatus) {
      case AtSignStatus.unavailable:
      case AtSignStatus.teapot:
        // New atSign that needs activation
        final apiKey = await Constants.appAPIKey;
        if (apiKey == null) {
          result = AtOnboardingResult.error(
            message: strings.errorAtSignNotExist,
          );
          break;
        }
        
        // Set up activation
        AtOnboardingConstants.setApiKey(apiKey);
        AtOnboardingConstants.rootDomain = util.config.atClientPreference.rootDomain;
        
        Map<String, String> apis = {
          "root.atsign.org": "my.atsign.com",
          "root.atsign.wtf": "my.atsign.wtf",
        };
        var regUrl = apis[util.config.atClientPreference.rootDomain];
        if (regUrl == null) {
          result = AtOnboardingResult.error(
            message: strings.errorRootDomainNotSupported,
          );
          break;
        }
        
        // Show activation dialog (this will be implemented by the onboarding library)
        result = await showDialog<AtOnboardingResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ActivateAtsignDialog(
            atSign: atsign,
            apiKey: apiKey,
            config: util.config,
            registrarUrl: regUrl,
            onboardingUtil: util,
            waitForTeapot: initialStatus != AtSignStatus.teapot,
          ),
        );
        break;
        
      case AtSignStatus.activated:
        // atSign exists but not in keychain - show APKAM flow
        final flowChoice = await showDialog<APKAMFlow?>(
          context: context,
          builder: (context) => const ApkamChoiceDialog(),
        );
        if (flowChoice == null) {
          result = AtOnboardingResult.cancelled();
          break;
        }
        
        if (flowChoice == APKAMFlow.atKeys) {
          // Upload atKeys file
          final statusStream = util.uploadAtKeysFile(atsign);
          result = await _handleFileUploadStatusStream(statusStream, atsign);
        } else {
          // APKAM enrollment
          final atClientPreference = await AtClientMethods.loadAtClientPreference(
            util.config.atClientPreference.rootDomain,
          );
          if (!mounted) return null;
          result = await showDialog<AtOnboardingResult>(
            context: context,
            builder: (context) => OnboardingApkamDialog(
              atsign: atsign,
              atClientPreference: atClientPreference,
            ),
          );
        }
        break;
        
      case AtSignStatus.notFound:
        result = AtOnboardingResult.error(
          message: strings.errorAtSignNotExist,
        );
        break;
        
      case null:
      case AtSignStatus.error:
        result = AtOnboardingResult.error(
          message: strings.errorAtServerUnavailable,
        );
        break;
    }
    return result;
  }

  Future<AtOnboardingResult?> _handleFileUploadStatusStream(Stream<FileUploadStatus> statusStream, String atsign) async {
    final strings = AppLocalizations.of(context)!;
    AtOnboardingResult? result;
    
    await for (FileUploadStatus status in statusStream) {
      switch (status) {
        case ErrorIncorrectKeyFile():
          result = AtOnboardingResult.error(message: strings.errorAtKeysInvalid);
          break;
        case ErrorAtSignMismatch():
          result = AtOnboardingResult.error(message: strings.errorAtKeysUploadedMismatch);
          break;
        case ErrorFailedFileProcessing():
          result = AtOnboardingResult.error(message: strings.errorAtKeysFileProcessFailed);
          break;
        case ErrorAtServerUnreachable():
          result = AtOnboardingResult.error(message: strings.errorAtServerUnavailable);
          break;
        case ErrorAuthFailed():
          result = AtOnboardingResult.error(message: strings.errorAuthenticatinFailed);
          break;
        case ErrorAuthTimeout():
          result = AtOnboardingResult.error(message: strings.errorAuthenticationTimedOut);
          break;
        case ErrorPairedAtsign _:
          result = AtOnboardingResult.error(message: strings.errorAtSignAlreadyPaired(status.atSign ?? atsign));
          break;
        case FilePickingCanceled():
          result = AtOnboardingResult.cancelled();
          break;
        case FileUploadAuthSuccess _:
          result = AtOnboardingResult.success(atsign: status.atSign ?? atsign);
          break;
        default:
          // Continue processing
          break;
      }
      if (result != null) break;
    }
    return result;
  }

  Future<void> _signOutFromAtSign(String atSign) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: Text('Are you sure you want to sign out from $atSign?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        setState(() => isLoading = true);
        
        // Navigate to loading page first
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoadingPage()),
          (route) => false,
        );
        
        // Perform sign out
        await preSignout();
        
        // Navigate to onboarding
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
            Routes.onboarding,
            (route) => false,
          );
        }
      } catch (e) {
        log('Sign out error: $e');
        if (mounted) {
          CustomSnackBar.error(content: 'Failed to sign out: $e');
          setState(() => isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    SizeConfig().init();
    
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CustomCard.dashboardContent(
                        height: deviceSize.height * Sizes.dashboardCardHeightFactor,
                        width: SizeConfig.setDashboardWidth(),
                        child: Column(
                          children: [
                            // Available AtSigns Section Title - Centered and larger
                            Text(
                              'Available atSigns',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            
                            // AtSigns List
                            Expanded(
                              child: availableAtSigns!.isEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.account_circle_outlined, size: 64, color: Colors.grey),
                                            SizedBox(height: 16),
                                            Text(
                                              'No atSigns available',
                                              style: TextStyle(fontSize: 18, color: Colors.grey),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Add a new atSign to get started',
                                              style: TextStyle(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: availableAtSigns!.length,
                                        itemBuilder: (context, index) {
                                          final atSign = availableAtSigns![index];
                                          final isCurrent = atSign == currentAtSign;
                                          
                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: isCurrent 
                                                        ? Theme.of(context).primaryColor
                                                        : Colors.grey.shade300,
                                                    child: Icon(
                                                      Icons.account_circle,
                                                      color: isCurrent ? Colors.white : Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        RichText(
                                                          text: TextSpan(
                                                            children: [
                                                              const TextSpan(
                                                                text: '@',
                                                                style: TextStyle(color: AppColor.primaryColor, fontSize: 16, fontWeight: FontWeight.w500),
                                                              ),
                                                              TextSpan(
                                                                text: atSign.split('@').last,
                                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (isCurrent) 
                                                          const Text(
                                                            'Currently active',
                                                            style: TextStyle(color: Colors.grey, fontSize: 12),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (!isCurrent) ...[
                                                        OutlinedButton.icon(
                                                          onPressed: () => _switchToAtSign(atSign),
                                                          icon: const Icon(Icons.swap_horiz, size: 16),
                                                          label: const Text('Switch'),
                                                          style: OutlinedButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        OutlinedButton.icon(
                                                          onPressed: () => _deleteAtSign(atSign),
                                                          icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                                          label: const Text('Remove', style: TextStyle(color: Colors.red)),
                                                          style: OutlinedButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            side: const BorderSide(color: Colors.red),
                                                          ),
                                                        ),
                                                      ] else ...[
                                                        OutlinedButton.icon(
                                                          onPressed: () => _signOutFromAtSign(atSign),
                                                          icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                                                          label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                                                          style: OutlinedButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            side: const BorderSide(color: Colors.red),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                            ),
                            
                            // Add New AtSign Button - Fixed width at bottom
                            const SizedBox(height: 16),
                            Center(
                              child: SizedBox(
                                width: 300,
                                child: ElevatedButton.icon(
                                  onPressed: _addNewAtSign,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add New atSign'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}