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
1. When sshnpd receives a session-based notification (`ssh_request`, `npt_request`, or legacy `sshd`), it attempts to create an immutable AtKey with the session ID
2. The first sshnpd instance to successfully create the key acquires the mutex and processes the request
3. Other instances receive an "immutable key" error and ignore the request
4. The mutex key has a TTL of 30 seconds to prevent stale locks

### Session ID Extraction
- **ssh_request/npt_request**: Session ID is extracted from the JSON payload
- **Legacy sshd**: Session ID is extracted from the space-separated payload (5th parameter for sshnp >=2.0.0 clients) or generated using notification ID for older clients

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
- If session ID extraction fails, the request proceeds without mutex for backward compatibility
- If mutex acquisition fails due to non-immutable errors, the request proceeds to maintain functionality
- Only immutable key errors trigger request rejection

### Logging
- Successful mutex acquisition: `😎 Will handle {type} request from {client}; acquired mutex {key}`
- Failed mutex acquisition: `🤷‍♂️ Will not handle {type} request from {client}; did not acquire session mutex (another sshnpd instance will handle this)`

## Benefits

1. **Load Balancing**: Multiple sshnpd instances can share the load automatically
2. **Redundancy**: If one instance fails, others can take over new sessions
3. **No Configuration Changes**: Existing clients work without modification
4. **Backward Compatibility**: Graceful degradation for older clients or parsing errors

## Testing

Unit tests verify:
- Session ID extraction from various notification formats
- Mutex acquisition success and failure scenarios
- Graceful handling of malformed notifications
- Backward compatibility behavior

## Usage

No configuration changes are required. Simply run multiple sshnpd instances with the same atSign and device name on different machines. The mutex mechanism will automatically ensure only one instance handles each session.
