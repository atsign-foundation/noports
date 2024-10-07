import 'package:npt_flutter/features/logging/models/loggable.dart';
import 'package:npt_flutter/features/logging/models/logging_bloc.dart';

class AtDirectoryCubit extends LoggingCubit<LoggableString> {
  AtDirectoryCubit() : super(const LoggableString('root.atsign.org'));

  void setRootDomain(String rootDomain) => emit(LoggableString(rootDomain));
  String getRootDomain() => (state.string);
}
