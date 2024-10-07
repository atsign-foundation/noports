// Hand this method the atSign you wish to offboard
// Returns: a boolean, true = success, false = failed
Future<bool> preSignout(String atSign) async {
  // We need to do the following before "signing out"
  // - Wipe all application state
  // - Remove the tray icon
  return true;
}
