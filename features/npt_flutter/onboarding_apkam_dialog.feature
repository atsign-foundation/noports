Feature: The enrollment dialog keeps a request until it is decided or the user abandons it

  Once this device has sent an enrollment request, NoPorts means to complete
  it: it waits for the request to be approved, denied or to expire, across
  restarts. Leaving the waiting screen without choosing Cancel (Back, closing
  the dialog, quitting the app) stops the wait and keeps the request's
  pending keys in the keychain, and the next sign-in through the
  Authenticator waits on it again without asking for an OTP. Only Cancel,
  once the user confirms it, abandons the request: its pending keys leave
  the keychain, and the OTP prompt says that trying again needs a new OTP
  from another enrollment and asks for the old request to be denied in the
  Authenticator. A request the atServer reports denied, expired or revoked
  is over, and its keys leave the keychain.

  Races: leaving stops the wait before the dialog goes, so an approval not
  yet written is never written by it; an approval and a Cancel resolve at
  the write to the keychain, and an approval written first stands, opened
  only once the wait has ended; an approval that lands while Cancel is being
  confirmed closes the confirmation; Cancel is not offered while one is in
  progress; tidying the keychain entry leaves a request filed meanwhile alone.
  Replay: none arises; leaving and Cancel send nothing, a resume polls the
  same enrollment, and trying again needs a new OTP.
  DoS: no poll runs once the user has left; denial, expiry and revocation end
  a wait that every restart would otherwise resume; Cancel is always offered
  while waiting.
  Forgery and impersonation: only the atServer's answer for this enrollment
  or a confirmed Cancel removes the request's keys; the dialog signs in only
  with a client opened on its own request's approval.

  Scenario: Leaving the waiting screen keeps the request
    Given the dialog waiting for approval of request e1
    When the user leaves it without choosing Cancel
    Then the wait is stopped, not cancelled, e1's pending keys stay in the keychain, and nothing is signed in

  Scenario: Leaving while the request is still being sent keeps it
    Given the dialog sending a request after the user entered an OTP
    When the user leaves before the atServer has answered
    Then the request's wait is stopped once it is in, never started, and its pending keys stay

  Scenario: Leaving while the dialog looks for a request to resume keeps it
    Given the dialog looking in the keychain for a request to resume
    When the user leaves before the lookup finds e1
    Then e1's wait is stopped, never started, and its pending keys stay

  @race
  Scenario: Leaving after the approval was written keeps the approved keys
    Given the approval of e1 written to the keychain, and its client opening
    When the user leaves
    Then that client is stopped, nothing is signed in, and the approved keys stay for the next sign-in

  Scenario: A restart resumes the wait
    Given the keychain holds e1, sent from this device for NoPorts and awaiting approval
    When the dialog opens for that atSign
    Then it waits on e1 without asking for an OTP, and sends no new request
