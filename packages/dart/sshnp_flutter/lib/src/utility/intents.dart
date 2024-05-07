import 'package:flutter/material.dart';

class ExitIntent extends VoidCallbackIntent {
  final void Function() onExit;
  const ExitIntent(this.onExit) : super(onExit);
  // modify this class to call on exit
}
