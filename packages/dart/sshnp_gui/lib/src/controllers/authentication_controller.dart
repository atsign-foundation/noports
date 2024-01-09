import 'package:at_contact/at_contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/repository/authentication_repository.dart';

/// A provider that exposes the [AuthenticationController] to the app.
final authenticationController = StateNotifierProvider<AuthenticationController, AsyncValue<List<String>?>>(
    (ref) => AuthenticationController(ref: ref));

/// A controller class that controls the UI update when the [AuthenticationRepository] methods are called.
class AuthenticationController extends StateNotifier<AsyncValue<List<String>?>> {
  final Ref ref;
  AuthenticationController({required this.ref}) : super(const AsyncValue.loading());

  /// Get list of contacts atsign for the current atsign.
  Future<void> getAtSignList() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async => await ref.watch(authenticationRepositoryProvider).getAtsignList());
  }

  /// Get the [AtContact] associated with the input atsign.
  Future<AtContact> getAtContact(String atSign) async {
    return await ref.watch(authenticationRepositoryProvider).getAtContact(atSign);
  }

  /// Get the current atsign.
  Future<String?> getCurrentAtSign() async {
    return ref.watch(authenticationRepositoryProvider).getCurrentAtSign();
  }

  /// Get the current atsign [AtContact].
  Future<AtContact> getCurrentAtContact() async {
    return await ref.watch(authenticationRepositoryProvider).getCurrentAtContact();
  }
}
