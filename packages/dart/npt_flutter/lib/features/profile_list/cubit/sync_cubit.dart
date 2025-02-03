import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SyncCubit extends Cubit<bool> {
  SyncCubit() : super(true);

  Future<void> checkSync() async {
    final value = await AtClientManager.getInstance().atClient.syncService.isInSync();
    log("SyncCubit: checkSync: $value");
    emit(value);
  }
}
