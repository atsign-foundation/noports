Feature: sshnpd adds a client's ssh public key to authorized_keys

  An sshnpd run with --sshpublickey adds the ssh public key an authorized
  Atsign sends it to the device user's ~/.ssh/authorized_keys. It writes one
  complete line that it builds itself, allowing logins only from the device's
  own loopback address, which is where every NoPorts ssh session reaches sshd.
  The Dart and C daemons behave the same.

  Races: two keys arriving together are each written on a line of their own.
  Replay: a re-delivered notification re-sends a key that is already present,
  which changes nothing; resending one needs the sender's or the device's
  atServer, which already holds more.
  DoS: a value over 8 KiB changes nothing; an authorized Atsign can add
  distinct keys without bound, but it can already add login keys, so a bound
  would deny it nothing.
  Forgery: a value writes at most one line, holding one key of a supported
  type whose key data is of that type, and a refused value cannot start a new
  line in sshnpd's log.
  Impersonation: the notification's sender is authenticated by the atServers
  and checked by sshnpd's authorization, which this does not change.

  Background:
    Given sshnpd runs with --sshpublickey
    And "@alice" is authorized to use the device
    And <K0>, <K1> and <K2> are the key data of three ed25519 public keys
    And <R1> is the key data of an RSA public key

  Scenario: a client's key is added as one line that allows only loopback logins
    Given authorized_keys holds the line "ssh-ed25519 <K0> user@laptop"
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>"
    Then authorized_keys holds the lines "ssh-ed25519 <K0> user@laptop" and 'from="127.0.0.1,::1" ssh-ed25519 <K1>'
    And authorized_keys ends with a newline

  Scenario: a key added after a last line with no newline starts a line of its own
    Given authorized_keys holds "ssh-ed25519 <K0> user@laptop" with no newline at its end
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>"
    Then authorized_keys holds the lines "ssh-ed25519 <K0> user@laptop" and 'from="127.0.0.1,::1" ssh-ed25519 <K1>'

  Scenario: two keys sent one after the other are each on a line of their own
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>"
    And "@alice" sends the sshpublickey "ssh-ed25519 <K2>"
    Then authorized_keys holds the lines 'from="127.0.0.1,::1" ssh-ed25519 <K1>' and 'from="127.0.0.1,::1" ssh-ed25519 <K2>'

  @race
  Scenario: two keys sent together are each on a line of their own
    When "@alice" sends the sshpublickeys "ssh-ed25519 <K1>" and "ssh-ed25519 <K2>" together
    Then authorized_keys holds the lines 'from="127.0.0.1,::1" ssh-ed25519 <K1>' and 'from="127.0.0.1,::1" ssh-ed25519 <K2>'

  @replay
  Scenario: a key already in authorized_keys is not added again
    Given authorized_keys holds the line 'from="127.0.0.1,::1" ssh-ed25519 <K1>'
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>"
    Then authorized_keys is unchanged

  Scenario: a key already in authorized_keys on a line of its own options is left as it is
    Given authorized_keys holds the line "ssh-ed25519 <K1> user@laptop"
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>"
    Then authorized_keys is unchanged

  Scenario: a key sent with a trailing newline keeps its comment
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1> user@client" followed by a newline
    Then authorized_keys holds the line 'from="127.0.0.1,::1" ssh-ed25519 <K1> user@client'

  Scenario: a key whose comment is not printable ASCII, or is over 256 characters, is added without it
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>" followed by a space and 257 "a" characters
    Then authorized_keys holds the line 'from="127.0.0.1,::1" ssh-ed25519 <K1>'
    And sshnpd logs at info that it left the comment out, without the comment's text

  Scenario: an RSA key named by its signature algorithm is written as ssh-rsa
    When "@alice" sends the sshpublickey "rsa-sha2-256 <R1>"
    Then authorized_keys holds the line 'from="127.0.0.1,::1" ssh-rsa <R1>'

  Scenario: the --sshpublickey-permissions value follows the loopback restriction
    Given sshnpd runs with --sshpublickey-permissions "no-pty"
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>"
    Then authorized_keys holds the line 'from="127.0.0.1,::1",no-pty ssh-ed25519 <K1>'

  Scenario: sshnpd refuses a --sshpublickey-permissions value holding its own from= option
    When sshnpd starts with --sshpublickey --sshpublickey-permissions 'from="10.0.0.0/8"'
    Then sshnpd exits, saying sshnpd sets the from= option itself

  @forgery
  Scenario: a value holding two key lines changes nothing
    Given authorized_keys holds the line "ssh-ed25519 <K0> user@laptop"
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>", a newline, then "ssh-ed25519 <K2>"
    Then authorized_keys is unchanged
    And sshnpd logs a warning naming "@alice"

  @forgery
  Scenario: a value whose key data is not of its stated key type changes nothing
    When "@alice" sends the sshpublickey "ssh-ed25519 <R1>"
    Then authorized_keys is unchanged

  @forgery
  Scenario: a value with a key type outside the supported list changes nothing
    When "@alice" sends the sshpublickey "ssh-dss <K1>"
    Then authorized_keys is unchanged

  @forgery
  Scenario: a refused value is logged on one line
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>", a newline, then "second line"
    Then sshnpd's warning shows the value with its newline escaped, on one log line, cut to at most 200 characters

  @dos
  Scenario: a value over 8 KiB changes nothing
    When "@alice" sends an sshpublickey of 8193 bytes
    Then authorized_keys is unchanged

  Scenario: sshnpd without --sshpublickey ignores a client's key
    Given sshnpd runs without --sshpublickey
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>"
    Then authorized_keys is unchanged

  Scenario: a key sent to a device with no ~/.ssh is added to a new authorized_keys only its owner can read
    Given the device user has no ~/.ssh directory
    When "@alice" sends the sshpublickey "ssh-ed25519 <K1>"
    Then ~/.ssh exists with mode 0700
    And authorized_keys exists with mode 0600, holding the line 'from="127.0.0.1,::1" ssh-ed25519 <K1>'

  Scenario: sshnpd starts on a device with no authorized_keys
    Given the device user has no ~/.ssh/authorized_keys
    When sshnpd starts
    Then sshnpd runs
    And no authorized_keys has been created
