import 'dart:developer';

class FormValidator {
  static const kEmptyFieldValidationError = 'Field cannot be left blank';
  static const kAtsignFieldValidationError = 'Field must start with @';
  static const kProfileNameFieldValidationError = 'Field must only use lower case alphanumeric characters and spaces';
  static const kPrivateKeyFieldValidationError = 'Field must only use lower case alphanumeric characters';
  static const kIntFieldValidationError = 'Field must only use numbers';
  static const kPortFieldValidationError = 'Field must use a valid port number';
  static const kPrivateKeyDropDownOption = 'Create a new private key';
  static String? validateRequiredField(String? value) {
    if (value?.isEmpty ?? true) {
      return kEmptyFieldValidationError;
    }
    return null;
  }

  static String? validateRequiredPortField(String? value) {
    String valid = r'^[0-9]+$';
    if (value?.isEmpty ?? true) {
      return kEmptyFieldValidationError;
    } else if (!RegExp(valid).hasMatch(value!)) {
      return kPortFieldValidationError;
    } else if (!(int.parse(value) >= 0 && int.parse(value) <= 65535)) {
      return kPortFieldValidationError;
    }
    return null;
  }

  static String? validateAtsignField(String? value) {
    if (value?.isEmpty ?? true) {
      return kEmptyFieldValidationError;
    } else if (!value!.startsWith('@')) {
      return kAtsignFieldValidationError;
    }
    validateRequiredField(value);
    return null;
  }

  static String? validateProfileNameField(String? value) {
    String invalid = '[^a-z0-9 ]';
    if (value?.isEmpty ?? true) {
      return kEmptyFieldValidationError;
    } else if (value!.contains(RegExp(invalid))) {
      return kProfileNameFieldValidationError;
    }
    return null;
  }

  static String? validatePrivateKeyField(String? value) {
    String invalid = '[^a-z0-9_]';
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
