import 'package:sshnp_gui/src/utility/constants.dart';

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
}
