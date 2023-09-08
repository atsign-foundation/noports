import 'package:sshnp_gui/src/utility/constants.dart';

class FormValidator {
  static String? validateRequiredField(String? value) {
    if (value!.isEmpty) {
      return kEmptyFieldValidationError;
    } else {
      return null;
    }
  }

  static String? validateAtsignField(String? value) {
    if (value!.isEmpty) {
      return kEmptyFieldValidationError;
    } else if (!value.startsWith('@')) {
      return kAtsignFieldValidationError;
    } else {
      return null;
    }
  }
}
