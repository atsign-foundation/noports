import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

final terminalSSHCommandProvider = StateProvider<String>(
  (ref) => '',
);
