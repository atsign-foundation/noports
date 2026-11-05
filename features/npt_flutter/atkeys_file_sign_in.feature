Feature: Signing in from an atKeys file backs its keys up to the keychain

  A sign-in from an atKeys file copies the file's keys into the keychain, so
  the next sign-in needs no file. An entry already holding a credential for
  the atSign is kept. An entry holding only enrollment requests this device
  was waiting on is replaced once the atServer has accepted the file's keys:
  those requests can no longer complete into a credential this device will
  use, so their pending keys leave the keychain, and the app log names each
  so the atSign's manager can deny it in the Authenticator. Until the
  atServer has accepted the file's keys, the entry is kept.

  Races: the entry is read, judged and replaced in one section under the
  keychain's write lock, so a Cancel still settling from a dialog the user
  left, which tidies under the same lock, either goes first and finds no
  request or goes second, finds the file's credential and leaves it alone.
  The replacement is one keychain write, so the keychain never holds nothing
  for the atSign, and a backup that fails leaves the entry as it was and the
  sign-in standing, since its client is already the one the app uses.
  Replay: none; nothing is sent.
  DoS: one keychain write per sign-in.
  Forgery: only keys the atServer has just accepted displace a request, and
  the keychain refuses keys stamped for another atSign.
  Impersonation: only the entry of the atSign signed in is touched, and a
  dropped request is never adopted.

  Scenario: A sign-in from an atKeys file replaces a pending-only keychain entry
    Given the keychain holds, for @alice, only the pending keys of request e1, and an atKeys file holding a credential for @alice that its atServer accepts
    When the user signs in with the file
    Then the keychain holds the file's keys for @alice and nothing of e1, read in one write section and replaced in one keychain write, the app log names e1 as dropped and to be denied in the Authenticator, and the next sign-in opens from the keychain

  Scenario: A sign-in from an atKeys file keeps a keychain entry holding a credential
    Given the keychain holds a credential for @alice
    When the user signs in with an atKeys file for @alice
    Then the keychain entry is left as it was

  Scenario: A sign-in the atServer has not accepted keeps a pending request
    Given the keychain holds only the pending keys of request e1 for @alice, and an atKeys file for @alice whose atServer cannot be reached
    When the user signs in with the file
    Then e1's pending keys stay in the keychain and nothing is written to it

  Scenario: A sign-in whose keychain backup fails still signs in
    Given the keychain holds only the pending keys of request e1 for @alice, and refuses every write
    When the user signs in with an atKeys file for @alice that its atServer accepts
    Then the sign-in succeeds and its client keeps running, e1's pending keys stay, and the app log says the file's keys were not backed up

  Scenario: A sign-in from an atKeys file with no keychain entry backs the keys up
    Given the keychain holds nothing for @alice
    When the user signs in with an atKeys file that its atServer accepts
    Then the keychain holds the file's keys for @alice

  @race
  Scenario: A Cancel settling after a file sign-in leaves the file's keys alone
    Given a confirmed Cancel of e1 still removing its keys, the dialog since left, and a file sign-in that has replaced @alice's entry with its credential
    When e1's Cancel finishes
    Then the file's keys are left alone
