# Sequence Diagram

This sequence diagram covers the "Happy path" for the startup of a NoPorts session. When a step fails with an error, then the client halts the process, all existing connections automatically timeout and shutdown after a short period of time.

```mermaid
sequenceDiagram
    participant c as client
    participant cs as client atServer
    participant rs as relay atServer
    participant r as relay
    participant ds as daemon atServer
    participant d as daemon

    note over c,d: Phase - Background services startup
    par
        r ->> rs: connect
        r ->> rs: pkam authenticate
        r ->> rs: monitor for notifications
    and
        d ->> ds: connect
        d ->> ds: pkam authenticate
        d ->> ds: monitor for notifications
    end


    note over c,d: Phase - Ping daemon
    c ->> cs: connect & pkam authenticate
    c ->> cs: monitor for notifications
    alt
        c ->> d: ping the daemon
        activate d
    else actual data flow
        c -->> cs: 
        cs -->> ds: 
        ds -->> d: 
    end


    note over c,d: Phase - Request relay session
    alt
        c ->> r: request two public ports from relay
    else actual data flow
        c -->> cs: 
        cs -->> rs: 
        rs -->> r: 
    end
    r ->> r: Request ephemeral ports from OS
    alt
        r ->> c: ports response from relay
    else actual data flow
        r -->> rs: 
        rs -->> cs: 
        cs -->> c: 
    end

    note over c,d: Phase - Receive ping response from daemon
    alt
        d ->> c: ping response (device info / features) from daemon
        deactivate d
    else actual data flow
        d -->> ds: 
        ds -->> cs: 
        cs -->> c: 
    end
    c ->> c: Validate request against daemon ping info

    note over c,d: Phase - Request daemon session
    alt
        c ->> d: send session request to the daemon
    else actual data flow
        c -->> cs: 
        cs -->> ds: 
        ds -->> d: 
    end
    d ->> d: Verify perimissions for client's request
    d -x r: [TCP - A] Reverse TCP the requested port to open relay port
    alt 
        d ->> c: session (success) response from daemon
    else actual data flow
        d -->> ds: 
        ds -->> cs: 
        cs -->> c: 
    end
    note over c,d: Phase - Client TCP connect
    c ->> c: Bind a local socket to expose the service on
    c -x r: [TCP - B] TCP connect to the other open relay port

    note over c,d: Phase - internal traffic relays (lasts  entire duration of the session)
    par
        r -->> r: relay all traffic from [TCP - A] to [TCP - B] and vice-versa
    and
        c -->> c: relay all traffic from [TCP - A] to local socket and vice-versa
    end
    note over c,d: Phase - using the connection
    c ->> c: You connect to the local socket as if it were the remote service!
```
