import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BackgroundSessionStatus { stopped, loading, running }

final backgroundSessionFamilyController =
    NotifierProviderFamily<BackgroundSessionFamilyController, BackgroundSessionStatus, String>(
  BackgroundSessionFamilyController.new,
);

class BackgroundSessionFamilyController extends FamilyNotifier<BackgroundSessionStatus, String> {
  @override
  BackgroundSessionStatus build(String arg) {
    return BackgroundSessionStatus.stopped;
  }

  void setStatus(BackgroundSessionStatus status) {
    state = status;
  }

  void start() => setStatus(BackgroundSessionStatus.loading);
  void endStartUp() => setStatus(BackgroundSessionStatus.running);
  void stop() => setStatus(BackgroundSessionStatus.stopped);
}
