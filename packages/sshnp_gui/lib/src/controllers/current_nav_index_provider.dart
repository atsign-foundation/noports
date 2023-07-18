import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => AppRoute.home.index);
