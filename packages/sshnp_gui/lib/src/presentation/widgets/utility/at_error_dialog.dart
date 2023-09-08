import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';

class AtErrorDialog {
  static Widget getAlertDialog(var error, BuildContext context) {
    var errorMessage = _getErrorMessage(error);
    var title = 'Error';
    return AlertDialog(
      title: Row(
        children: [
          Text(
            title,
          ),
          const Icon(Icons.sentiment_dissatisfied)
        ],
      ),
      content: Text(errorMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Close'),
        )
      ],
    );
  }

  ///Returns corresponding errorMessage for [error].
  static String _getErrorMessage(var error) {
    switch (error.runtimeType) {
      case AtClientException:
        return 'Unable to perform this action. Please try again.';

      case UnAuthenticatedException:
        return 'Unable to authenticate. Please try again.';

      case NoSuchMethodError:
        return 'Failed in processing. Please try again.';

      case AtConnectException:
        return 'Unable to connect server. Please try again later.';

      case AtIOException:
        return 'Unable to perform read/write operation. Please try again.';

      case AtServerException:
        return 'Unable to activate server. Please contact admin.';

      case SecondaryNotFoundException:
        return 'Server is unavailable. Please try again later.';

      case SecondaryConnectException:
        return 'Unable to connect. Please check with network connection and try again.';

      case InvalidAtSignException:
        return 'Invalid atsign is provided. Please contact admin.';

      case String:
        return error;

      default:
        return 'Unknown error.';
    }
  }
}
