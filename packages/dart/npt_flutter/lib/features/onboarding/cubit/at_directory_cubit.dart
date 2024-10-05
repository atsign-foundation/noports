import 'package:flutter_bloc/flutter_bloc.dart';

class AtDirectoryCubit extends Cubit<String> {
  AtDirectoryCubit() : super('root.atsign.org');

  void setRootDomain(String rootDomain) => emit(rootDomain);
}
