import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BackgroundSessionStatus { stopped, loading, running }

final backgroundSessionFamilyController =
    NotifierProviderFamily<BackgroundSessionFamilyController, BackgroundSession, String>(
  BackgroundSessionFamilyController.new,
);

class BackgroundSession {
  final String profileName;
  BackgroundSessionStatus status = BackgroundSessionStatus.stopped;

  BackgroundSession(this.profileName);
}

class BackgroundSessionFamilyController extends FamilyNotifier<BackgroundSession, String> {
  @override
  BackgroundSession build(String arg) {
    return BackgroundSession(arg);
  }

  BackgroundSessionStatus get status => state.status;

  void setStatus(BackgroundSessionStatus status) => state.status = status;

  void start() => setStatus(BackgroundSessionStatus.loading);
  void endStartUp() => setStatus(BackgroundSessionStatus.running);
  void stop() => setStatus(BackgroundSessionStatus.stopped);
}
