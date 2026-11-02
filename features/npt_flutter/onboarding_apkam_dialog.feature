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

  Scenario: Cancel asks first
    Given the dialog waiting for approval of e1
    When the user chooses Cancel
    Then a confirmation names e1 and the atSign, and says this abandons the request and that trying again needs a new OTP from another enrollment; the wait goes on and the keys stay

  Scenario: A declined Cancel changes nothing
    Given that confirmation
    When the user chooses Keep waiting, or dismisses the confirmation
    Then it closes, the wait goes on, and the keys stay

  Scenario: A confirmed Cancel abandons the request
    Given that confirmation
    When the user confirms
    Then the wait is cancelled, e1's pending keys leave the keychain, and the OTP prompt says e1 was abandoned, that a new OTP from another enrollment is needed, and to deny e1 in the Authenticator; nothing is signed in

  Scenario: A confirmed Cancel that cannot remove the keys says so, and Cancel retries
    Given that confirmation, and a keychain that refuses the update
    When the user confirms
    Then the dialog says e1 could not be abandoned and its keys are still in the keychain, its wait has ended, and it offers Cancel again; choosing it retries without asking again, and once the keys go the OTP prompt says e1 was abandoned

  Scenario: Leaving after a Cancel that could not remove the keys keeps the request
    Given the dialog saying e1 could not be abandoned
    When the user leaves
    Then e1's pending keys stay, and the next time the dialog opens it waits on e1 again

  @race
  Scenario: Cancel is not offered again while one is in progress
    Given a confirmed Cancel whose removal of the keys has not finished
    When the user looks for Cancel
    Then it is not offered, and cancel has run once

  @race
  Scenario: An approval landing while Cancel is being confirmed signs in
    Given the Cancel confirmation showing
    When the approval arrives and the client opens
    Then the confirmation closes, nothing is cancelled, and the dialog signs in with that client

  @race
  Scenario: A confirmed Cancel after the approval was written lets the approval stand
    Given the confirmation, and the approval of e1 written to the keychain just before cancel runs
    When the user confirms
    Then once the wait has ended, the dialog opens a client on the approved keys and signs in with it; the approved keys stay as written and no OTP is asked for

  @race
  Scenario: A Cancel press after the approval opened the client does nothing
    Given the approval of e1 has arrived and its client has opened
    When a Cancel press arrives before the screen changes
    Then nothing is cancelled, and the dialog signs in with the approved client

  @race
  Scenario: A request filed while a Cancel settles is left alone
    Given a confirmed Cancel of e1 still removing its keys, the dialog since left, and request e2 filed in the keychain for the atSign
    When e1's Cancel finishes
    Then e2's keys are left alone

  Scenario: A revoked request asks for a new OTP
    Given the dialog waiting for approval of e1
    When the atServer reports e1 revoked (AT0027)
    Then e1's keys leave the keychain, and the OTP prompt says the request was revoked; nothing is signed in

  Scenario: A denied request is reported as denied
    Given the dialog waiting for approval of e1
    When the atServer reports e1 denied (AT0025)
    Then e1's keys leave the keychain, and the dialog says the request was denied and closes with that error

  Scenario: An expired request asks for a new OTP
    Given the dialog waiting for approval of e1
    When the atServer reports e1 expired (AT0028)
    Then e1's keys leave the keychain, and the OTP prompt says the request expired

  Scenario: A wait that ends without a decision keeps the request
    Given the dialog waiting for approval of e1
    When the wait ends because the atServer could not be reached, or refused e1 for a reason other than denial, expiry or revocation
    Then e1's pending keys stay, the dialog closes with what went wrong and does not report a denial, and the next sign-in through the Authenticator waits on e1 again

  Scenario: An approval written before the client fails to open keeps the approved keys
    Given the approval of e1 written to the keychain
    When the client then fails to open
    Then the approved keys stay, and the dialog closes with the error, not as denied
