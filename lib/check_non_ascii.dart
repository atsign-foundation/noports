bool checkNonAscii(String test) {
  var extra = test.replaceAll(RegExp(r'[a-zA-Z0-9_]*'), '');
  if ((extra != '') || (test.length > 15)) {
    return true;
  } else {
    return false;
  }
}
