import 'dart:async';
import 'dart:io';

Future <bool> fileExists(String file) async  {
   bool f = await File(file).exists();
   return f;
  }
