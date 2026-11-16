Feature: policy_tests runs cases that share a policy atSign one at a time

  Every policy case opens the policy atSign's admin client in its own setup,
  and at_client lets one process hold one client per atSign and enrollment,
  so a case's setup stops any sibling's. Cases that share a policy atSign
  therefore run in sequence whatever --batch-size says; batches for different
  policy versions still run in sequence as before.

  Races: the subject; no two cases hold the policy atSign's client at once.
  Replay: none. DoS: one admin client at a time. Forgery and impersonation:
  unchanged; the keys and the atSigns are the same.

  @race
  Scenario: Concurrent policy cases do not share a policy atSign
    Given two policy cases in one batch, both administering the same policy atSign
    When the pack runs them with --batch-size 2
    Then the second starts only once the first has finished, and each opens the admin client it uses

  Scenario: Cases administering different policy atSigns run at once
    Given two policy cases in one batch, administering different policy atSigns
    When the pack runs them with --batch-size 2
    Then the second starts while the first is running
