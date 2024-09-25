// This file contains the form validation logic for the app. It is used to validate the input fields in the app.

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';

class FormValidator {
  static String? validateRequiredField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    }
    return null;
  }

  static String? validateRequiredAtsignField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    if (!value!.startsWith('@')) {
      return strings.validationErrorAtsignField;
    }
    validateRequiredField(value);
    return null;
  }

  static String? validateOptionalAtsignField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    if (!value!.startsWith('@')) {
      return strings.validationErrorAtsignField;
    }

    return null;
  }

  static String? validateEmptyAtsignField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    if (value?.isEmpty ?? true) {
      return null;
    } else if (!value!.startsWith('@')) {
      return strings.validationErrorAtsignField;
    }
    validateRequiredField(value);
    return null;
  }

  static String? validateProfileNameField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    String invalid = r'[^a-z0-9 ]';
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    } else if (value!.contains(RegExp(invalid))) {
      return strings.validationErrorProfileNameField;
    }
    return null;
  }

  static String? validateDeviceNameField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    String invalid = r'[^a-z0-9_]{1,36}';
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    } else if (value!.contains(RegExp(invalid))) {
      return strings.validationErrorDeviceNameField;
    } else if (value.length > 36) {
      return strings.validationErrorLongField;
    }
    return null;
  }

  static String? validateLocalPortField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;

    var port = int.tryParse(value ?? '');
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    } else if (value == '0') {
      return null;
    } else if (port == null || !(port >= 1024 && port <= 65535)) {
      return strings.validationErrorLocalPortField;
    }
    return null;
  }

  static String? validateRemotePortField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;

    var port = int.tryParse(value ?? '');
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    } else if (port == null || !(port >= 1 && port <= 65535)) {
      return strings.validationErrorRemotePortField;
    }
    return null;
  }

  static String? validateRemoteHostField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    String valid =
        r'^(?:(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}|localhost|(?:\d{1,3}\.){3}\d{1,3}|(?:[a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4})$';
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    } else if (!value!.contains(RegExp(valid))) {
      return strings.validationErrorRemoteHostField;
    }
    return null;
  }
}
