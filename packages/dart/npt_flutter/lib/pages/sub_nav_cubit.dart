import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/routes.dart';

class SubNavCubit extends Cubit<String> {
  SubNavCubit() : super(HomeRoutes.dashboard);

  void setSubRoute(String routeName) => emit(routeName);
}
