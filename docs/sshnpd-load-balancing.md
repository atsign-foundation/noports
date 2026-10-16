# Session-Based Mutex for sshnpd Load Balancing

## Overview

This document describes the session-based mutex mechanism implemented in sshnpd to enable load balancing and redundancy across multiple sshnpd daemon instances listening on the same atSign and device name.

## Problem

Previously, when multiple sshnpd daemons were running on different machines but configured with the same atSign and device name, all daemons would respond to incoming connection notifications, causing confusion and connection failures.

## Solution

A session-based mutex mechanism similar to the one used in srvd.dart has been implemented. When a session-based request is received, only one sshnpd instance will acquire the mutex and handle the request, while others will ignore it.

## How It Works

### Mutex Key Generation
For each session-based request, a mutex key is generated using the pattern:
```
{sessionId}.session_mutexes.{namespace}{deviceAtSign}
```

### Mutex Acquisition
1. When sshnpd receives a session-based notification (`ssh_request`, `npt_request`, or legacy `sshd`), it takes at_client's server mutex (`tryAcquireServerMutex`) on that key: an immutable record written straight to the atServer with `:nc`, so it reaches no client's sync and, on atServers from c3.16.3 and p3.16.5, leaves no commit log entry
2. The first sshnpd instance to create the record acquires the mutex and processes the request
3. Other instances find the record already there and ignore the request. Daemons from earlier releases write the same immutable record, so a group of daemons on mixed releases still lets only one instance handle each session
4. The mutex key has a TTL of 30 seconds to prevent stale locks

### Session ID Extraction
- **ssh_request/npt_request**: Session ID is extracted from the JSON payload
- **Legacy sshd**: Session ID is extracted from the space-separated payload (5th parameter for sshnp >=2.0.0 clients) or generated using notification ID for older clients
- A session ID the client supplies must be a UUID. A request whose session ID is missing or isn't a UUID is refused before the mutex is attempted; a legacy `sshd` request from a client too old to send one is the only request without one that proceeds

### Supported Request Types
- `ssh_request` - Modern SSH connection requests
- `npt_request` - Network packet tunnel requests  
- `sshd` - Legacy SSH connection requests

### Non-Session Requests
Requests that don't have sessions (like `ping`, `sshpublickey`, `privatekey`) are processed by all daemons without mutex, as they don't require exclusive handling.

## Implementation Details

### Key Methods
- `tryAcquireSessionMutex()`: Attempts to acquire mutex for a session-based request
- `extractSessionId()`: Extracts session ID from different notification formats

### Error Handling
- If the session ID can't be extracted, or isn't a UUID, the request is refused and logged at warning, before the mutex is attempted
- If the mutex can't be taken for any other reason, such as an atServer older than p3.13.0, which doesn't accept `:nc`, the request proceeds and the failure is logged at warning
- Only a lock record that already exists makes an instance ignore the request

### Logging
- Successful mutex acquisition: `😎 Will handle {type} request from {client}; acquired mutex {key}`
- Failed mutex acquisition: `🤷‍♂️ Will not handle {type} request from {client}; did not acquire session mutex (another sshnpd instance will handle this)`
- Mutex not taken for another reason: `Will handle {type} request from {client} without a session mutex, which could not be taken: {error}`
- Refused request: `Refusing {type} request {notification id} from {client}: its sessionId is missing or not a UUID`

## Benefits

1. **Load Balancing**: Multiple sshnpd instances can share the load automatically
2. **Redundancy**: If one instance fails, others can take over new sessions
3. **No Configuration Changes**: Existing clients work without modification
4. **Backward Compatibility**: Graceful degradation for older clients

## Testing

Unit tests verify:
- Session ID extraction from various notification formats
- Mutex acquisition success and failure scenarios
- Graceful handling of malformed notifications
- Refusal, before the mutex, of a session ID which is missing or isn't a UUID
- Backward compatibility behavior

## Usage

No configuration changes are required. Simply run multiple sshnpd instances with the same atSign and device name on different machines. The mutex mechanism will automatically ensure only one instance handles each session, provided the device atSign's atServer is p3.13.0 or later; on an older one, every instance handles every session request.
