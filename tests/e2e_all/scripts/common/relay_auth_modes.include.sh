#!/bin/bash
# Proves features/srvd/mixed_relay_auth.feature from the relay's own log.

predatesEscrScenario="A current client and a daemon that predates ESCR are each verified in their own mode"
supportsEscrScenario="A current client and a daemon that supports ESCR are both verified by ESCR"

# Prints ESCR or LEGACY, the mode a daemon of this type and version speaks to
# a relay that auto-detects; prints nothing for a daemon it doesn't know.
expectedDaemonRelayAuthMode() {
  local typeAndVersion="$1"
  case "$typeAndVersion" in
  d:current | c:current) echo "ESCR" ;;
  d:* | c:*)
    if [[ $(versionIsLessThan "$typeAndVersion" "d:5.10.0 c:1.1.0") == "true" ]]; then
      echo "LEGACY"
    else
      echo "ESCR"
    fi
    ;;
  esac
}

# Prints how many of the relay's verified sockets for one side of a session
# were verified in a mode: countVerified <relayLog> <sessionId> <side> <mode>
countVerified() {
  grep -F "RelayAuthVerifierAuto ($2 $3)" "$1" |
    grep -c -F "Auto-detected $4; verification success"
}

# Prints how many of one side's sockets the detection window settled as ESCR.
countSettledByWindow() {
  grep -F "RelayAuthVerifierAuto ($2 $3)" "$1" | grep -c -F "assuming ESCR"
}

# Prints how many of one side's sockets failed verification.
countFailed() {
  grep -F "RelayAuthVerifierAuto ($2 $3)" "$1" | grep -c -F "auto verification FAILED"
}

# Checks one side of a session: at least one socket verified, every one in
# the expected mode, none failed. checkSide <relayLog> <sessionId> <side> <expectedMode>
checkSide() {
  local relayLog="$1" sessionId="$2" side="$3" expected="$4"
  local other="ESCR"
  [[ "$expected" == "ESCR" ]] && other="LEGACY"
  local expectedCount otherCount failedCount windowCount
  expectedCount=$(countVerified "$relayLog" "$sessionId" "$side" "$expected")
  otherCount=$(countVerified "$relayLog" "$sessionId" "$side" "$other")
  failedCount=$(countFailed "$relayLog" "$sessionId" "$side")
  windowCount=$(countSettledByWindow "$relayLog" "$sessionId" "$side")
  logInfo "    relay verified $side of $sessionId: $expectedCount by $expected, $otherCount by $other, $failedCount failed; $windowCount settled by the detection window"
  if ((expectedCount < 1 || otherCount > 0 || failedCount > 0)); then
    logError "    $side of session $sessionId was not verified by $expected alone"
    return 1
  fi
}

# Checks the relay verified every socket of the session npt opened in the mode
# its side speaks. checkRelayAuthModes <nptStderrFile> <daemonTypeAndVersion> <relayLog>
checkRelayAuthModes() {
  local nptStderrFile="$1" daemonTypeAndVersion="$2" relayLog="$3"

  if [[ ! -r "$relayLog" ]]; then
    logError "    the relay log $relayLog cannot be read"
    return 1
  fi
  local expectedB
  expectedB=$(expectedDaemonRelayAuthMode "$daemonTypeAndVersion")
  if [[ -z "$expectedB" ]]; then
    logError "    no relay auth mode is known for daemon $daemonTypeAndVersion"
    return 1
  fi
  if ! grep -q -F '"autoDetectsRelayAuth":true' "$nptStderrFile"; then
    logError "    the relay's response to npt does not say it auto-detects relay auth"
    return 1
  fi
  local sessionId
  sessionId=$(grep -o -E 'Sending definitive auth modes to srvd: \{"sessionId":"[0-9a-fA-F-]{36}"' "$nptStderrFile" |
    head -n 1 | grep -o -E '[0-9a-fA-F-]{36}' | tr 'A-F' 'a-f')
  if [[ -z "$sessionId" ]]; then
    logError "    npt logged no session id with its auth modes"
    return 1
  fi

  for _ in {1..4}; do
    if (($(countVerified "$relayLog" "$sessionId" sideA ESCR) + $(countVerified "$relayLog" "$sessionId" sideA LEGACY) > 0)) &&
      (($(countVerified "$relayLog" "$sessionId" sideB ESCR) + $(countVerified "$relayLog" "$sessionId" sideB LEGACY) > 0)); then
      break
    fi
    sleep 0.5
  done

  checkSide "$relayLog" "$sessionId" sideA ESCR || return 1
  checkSide "$relayLog" "$sessionId" sideB "$expectedB" || return 1

  if [[ "$expectedB" == "LEGACY" ]]; then
    logInfo "    Scenario PASSED: $predatesEscrScenario"
  else
    logInfo "    Scenario PASSED: $supportsEscrScenario (daemon: $(getVersionDescription "$daemonTypeAndVersion"))"
  fi
}
