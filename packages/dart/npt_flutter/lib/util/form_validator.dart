// This file contains the form validation logic for the app. It is used to validate the input fields in the app.

import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

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
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    } else if (!value!.startsWith('@') || value.length < 2) {
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
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
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
      return strings.validationErrorLocalPortField;
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

  static String? validateHostField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    String valid =
        r'^(?:(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)$';
    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    } else if (!value!.contains(RegExp(valid))) {
      return strings.validationErrorHostField;
    }
    return null;
  }

  static String? validateEmptyRelayField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    if (value?.isEmpty ?? true) {
      return null;
    } else if (!value!.startsWith('@') || value.length < 2) {
      return strings.validationErrorRelayField;
    }
    validateRequiredField(value);
    return null;
  }

  static String? validateHostPortField(String? value) {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;

    if (value?.isEmpty ?? true) {
      return strings.validationErrorEmptyField;
    }

    // Check if the value contains at least one colon
    if (!value!.contains(':')) {
      return 'Host:port format must contain at least one colon (:)';
    }

    // Split by colon and validate parts
    final parts = value.split(':');
    if (parts.length < 2) {
      return 'Host:port format must contain at least one colon (:)';
    }

    // Validate host part (first part)
    final host = parts[0];
    if (host.isEmpty) {
      return 'Host part cannot be empty';
    }

    // Validate port part (last part)
    final portStr = parts.last;
    if (portStr.isEmpty) {
      return 'Port part cannot be empty';
    }

    final port = int.tryParse(portStr);
    if (port == null || !(port >= 1 && port <= 65535)) {
      return 'Port must be a valid number between 1 and 65535';
    }

    return null;
  }
}
