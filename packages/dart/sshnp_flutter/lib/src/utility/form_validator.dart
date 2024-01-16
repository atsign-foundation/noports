import 'dart:developer';

import 'package:sshnp_flutter/src/utility/constants.dart';

class FormValidator {
  static String? validateRequiredField(String? value) {
    if (value?.isEmpty ?? true) {
      return kEmptyFieldValidationError;
    }
    return null;
  }

  static String? validateAtsignField(String? value) {
    if (value?.isEmpty ?? true) {
      return kEmptyFieldValidationError;
    } else if (!value!.startsWith('@')) {
      return kAtsignFieldValidationError;
    }
    return null;
  }

  static String? validateProfileNameField(String? value) {
    String invalid = '[^a-zA-Z0-9 ]';
    if (value?.isEmpty ?? true) {
      return kEmptyFieldValidationError;
    } else if (value!.contains(RegExp(invalid))) {
      return kProfileNameFieldValidationError;
    }
    return null;
  }

  static String? validatePrivateKeyField(String? value) {
    String invalid = '[^a-zA-Z0-9_]';
    if (value?.isEmpty ?? true) {
      return kEmptyFieldValidationError;
    } else if (value! == kPrivateKeyDropDownOption) {
      return kPrivateKeyFieldValidationError;
    } else if (value.contains(RegExp(invalid))) {
      return kPrivateKeyFieldValidationError;
    }
    return null;
  }

  static String? validateMultiSelectStringField(List<String>? value) {
    if (value == null || value.isEmpty) {
      log('value is empty');
      return kEmptyFieldValidationError;
    }

    return null;
  }
}
