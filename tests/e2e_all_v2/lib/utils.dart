import 'dart:io';

Future<bool> ensureDirectoryExists(final Directory directory) async {
  if (await directory.exists()) {
    return true;
  }
  try {
    await directory.create(recursive: true);
    return true;
  } catch (e) {
    throw Exception('Failed to create directory ${directory.path}: $e');
  }
}

