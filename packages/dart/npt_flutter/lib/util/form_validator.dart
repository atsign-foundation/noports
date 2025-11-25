// This file contains the form validation logic for the app. It is used to validate the input fields in the app.

import 'dart:io';

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
    } else if (!value!.contains(RegExp(valid)) &&
        InternetAddress.tryParse(value) == null) {
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
    if (value?.isEmpty ?? true) {
      return 'This field is required';
    }

    // Check if the value contains at least one colon
    if (!value!.contains(':')) {
      return 'Host:port format must contain a colon (:) separating host and port';
    }

    // Split by colon - IPv6 addresses like ::1:443 will have multiple parts
    final parts = value.split(':');
    if (parts.length < 2) {
      return 'Host:port format must contain a colon (:) separating host and port';
    }

    // Port is always the last part
    final portStr = parts.last;
    if (portStr.isEmpty) {
      return 'Port part cannot be empty';
    }

    // Allow wildcard for port, otherwise validate it's a valid port number
    if (portStr != '*') {
      final port = int.tryParse(portStr);
      if (port == null || !(port >= 1 && port <= 65535)) {
        return 'Port must be a valid number between 1 and 65535, or use * for wildcard';
      }
    }

    // Host is everything except the last part (the port)
    // Rebuild the host by joining all parts except the last with ':'
    final hostParts = parts.sublist(0, parts.length - 1);
    final host = hostParts.join(':');

    // Check if host is empty
    if (host.isEmpty) {
      return 'Host part cannot be empty';
    }

    return null;
  }
}
