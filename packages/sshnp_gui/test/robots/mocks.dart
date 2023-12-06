import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';

class MockTerminalSessionController extends Notifier<String> with Mock implements TerminalSessionController {
  @override
  String build() {
    return '';
  }

  @override
  String createSession() {
    state = 'test terminal';
    return state;
  }

  @override
  void setSession(String sessionId) {
    state = sessionId;
  }
}

final mockTerminalSessionController = NotifierProvider<TerminalSessionController, String>(
  MockTerminalSessionController.new,
);

class MockTerminalSessionListController extends Notifier<List<String>>
    with Mock
    implements TerminalSessionListController {
  @override
  List<String> build() {
    return [];
  }
}

final mockTerminalSessionListController = NotifierProvider<TerminalSessionListController, List<String>>(
  MockTerminalSessionListController.new,
);

class MockConfigListController extends AutoDisposeAsyncNotifier<Iterable<String>>
    with Mock
    implements ConfigListController {
  static Iterable<String> _mockConfigList = const Iterable.empty();

  @override
  Future<Iterable<String>> build() async {
    return Future<Iterable<String>>.value(_mockConfigList);
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  @override
  void add(String profileName) {
    _mockConfigList = {..._mockConfigList, profileName};
    state = AsyncValue.data(_mockConfigList);
  }

  @override
  void remove(String profileName) {
    _mockConfigList = _mockConfigList.where((element) => element != profileName);
    state = AsyncValue.data(_mockConfigList);
  }

  void throwError() {
    state = AsyncError('Error', StackTrace.fromString('Error'));
  }
}

final mockConfigListController = AutoDisposeAsyncNotifierProvider<MockConfigListController, Iterable<String>>(
  MockConfigListController.new,
);

class MockConfigFamilyController extends AutoDisposeFamilyAsyncNotifier<SshnpParams, String>
    with Mock
    implements ConfigFamilyController {
  late final SshnpParams _mockConfig = SshnpParams.empty();

  @override
  Future<SshnpParams> build(String profileName) async {
    return Future<SshnpParams>.value(_mockConfig);
  }

  @override
  Future<void> putConfig(SshnpParams params, {String? oldProfileName, BuildContext? context}) {
    state = AsyncValue.data(params);
    ref.read(mockConfigListController.notifier).add(params.profileName!);
    return Future<void>.value();
  }

  @override
  Future<void> deleteConfig({BuildContext? context}) async {
    ref.read(mockConfigListController.notifier).remove(state.value!.profileName!);
  }

  // void throwError(String profileName) {
  //   state = {profileName: AsyncError('Error', StackTrace.fromString('Error'))};
  // }
}

final mockConfigFamilyController = AutoDisposeAsyncNotifierProviderFamily<ConfigFamilyController, SshnpParams, String>(
  MockConfigFamilyController.new,
);
