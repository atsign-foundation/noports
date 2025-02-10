import 'package:equatable/equatable.dart';
import 'package:noports_installer/src/types.dart';

// enums

enum InstallType {
  binary,
  service,
  atKeys,
}

enum NppVariant {
  atServer,
  file,
}

// Base types

sealed class InstallStep with EquatableMixin {
  const InstallStep();
  InstallType get type;
  @override
  List<Object?> get props => [];
}

abstract class InstallBinary extends InstallStep {
  const InstallBinary();

  @override
  final InstallType type = InstallType.binary;

  Set<InstallStep>? get dependencies => null;
}

abstract class LanguagedInstallBinary extends InstallBinary {
  final BinaryLanguage language;
  const LanguagedInstallBinary(this.language);
}

abstract class SetupAtKeys extends InstallStep {
  const SetupAtKeys();

  @override
  final InstallType type = InstallType.atKeys;
}

abstract class InstallService extends InstallStep {
  final InstallBinary? serviceBinary;
  const InstallService(this.serviceBinary);

  @override
  final InstallType type = InstallType.service;
}

abstract class LanguagedInstallService extends InstallService {
  const LanguagedInstallService(LanguagedInstallBinary super.serviceBinary);

  @override
  LanguagedInstallBinary get serviceBinary =>
      super.serviceBinary as LanguagedInstallBinary;
}

// Sealed types

class InstallClientBinaries extends InstallBinary {
  const InstallClientBinaries();

  @override
  Set<InstallStep> get dependencies =>
      {InstallSshnpBinary(), InstallNptBinary()};
}

// Only Dart binary
class InstallSshnpBinary extends InstallBinary {
  const InstallSshnpBinary();

  @override
  Set<InstallStep> get dependencies => {InstallSrvBinary(BinaryLanguage.dart)};
}

// Only Dart binary
class InstallNptBinary extends InstallBinary {
  const InstallNptBinary();

  @override
  Set<InstallStep> get dependencies => {InstallSrvBinary(BinaryLanguage.dart)};
}

// Dart and C binaries
class InstallSshnpdBinary extends LanguagedInstallBinary {
  const InstallSshnpdBinary(super.language);

  @override
  Set<InstallStep> get dependencies => {InstallSrvBinary(language)};
}

// Dart and C binaries
class InstallSshnpdService extends LanguagedInstallService {
  const InstallSshnpdService(super.serviceBinary);

  @override
  List<Object?> get props => [serviceBinary];
}

// Dart and C binaries
class InstallAtActivateBinary extends LanguagedInstallBinary {
  const InstallAtActivateBinary(super.language);

  @override
  List<Object?> get props => [language];
}

// Dart and C binaries
class InstallSrvBinary extends LanguagedInstallBinary {
  const InstallSrvBinary(super.language);

  @override
  List<Object?> get props => [language];
}

// Only Dart binary
class InstallSrvdBinary extends InstallBinary {
  const InstallSrvdBinary();
  @override
  Set<InstallStep> get dependencies => {InstallSrvBinary(BinaryLanguage.dart)};
}

class InstallSrvdService extends InstallService {
  const InstallSrvdService() : super(const InstallSrvdBinary());
}

class InstallNppBinary extends InstallBinary {
  final Set<NppVariant> variants;
  const InstallNppBinary(this.variants);

  @override
  List<Object?> get props => [variants];
}

class InstallNpaBinary extends InstallBinary {
  const InstallNpaBinary();
}

class SetupApkamKeys extends SetupAtKeys {
  const SetupApkamKeys();
}

class ActivateAtsign extends SetupAtKeys {
  const ActivateAtsign();
}
