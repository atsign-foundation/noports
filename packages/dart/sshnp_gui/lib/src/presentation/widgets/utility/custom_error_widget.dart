import 'dart:developer';

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/material.dart';

class CustomErrorWidget extends StatelessWidget {
  final Object error;

  static String getErrorMessage(Object error) {
    if (error is AuthException) {
      AuthException e = error;
      if (e.code == AuthExceptionCode.userCanceled) {
        return 'Operation canceled by user';
      } else if (e.code == AuthExceptionCode.timeout) {
        return 'Operation timed out. Please try again';
      } else {
        log(e.toString());
        return 'An error occurred while retrieving the private key list. Please try again.';
      }
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  const CustomErrorWidget({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(getErrorMessage(error)));
  }
}
