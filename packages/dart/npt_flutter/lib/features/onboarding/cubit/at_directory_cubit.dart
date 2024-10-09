import 'package:npt_flutter/features/logging/models/logging_bloc.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';

class AtDirectoryCubit extends LoggingCubit<AtsignInformation> {
  AtDirectoryCubit() : super(const AtsignInformation(atSign: '', rootDomain: 'root.atsign.org'));

  void setRootDomain(String rootDomain) => emit(AtsignInformation(atSign: state.atSign, rootDomain: rootDomain));
  String getRootDomain() => (state.rootDomain);

  void setAtSign(String atSign) => emit(AtsignInformation(atSign: atSign, rootDomain: state.rootDomain));
  String getAtSign() => (state.atSign);
}
