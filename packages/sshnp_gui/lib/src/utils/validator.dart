import 'constants.dart';

class Validator {
  static String? validateRequiredField(String? value) {
    if (value!.isEmpty) {
      return kEmptyFieldValidationError;
    } else {
      return null;
    }
  }
}
