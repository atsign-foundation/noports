---
icon: engine
---

# Under The Hood

{% hint style="info" %}
This document describes version 5.6.x Other versions use a different method of forming the connection.
{% endhint %}

## Overview

There are four atSigns involved - one for each of

* the noports daemon program (`sshnpd`) which runs on the device you want to ssh to
* the noports client programs (`sshnp/npt`) which you run on the device you want to ssh from
* the noports tcp rendezvous program (`sshrvd`)
* if required a policy engine

The programs communicate via the atProtocol and the atClient SDKs; as a result, the payloads of the messages the programs send to each other are all end-to-end encrypted.

In brief

* The client (`sshnp/npt`) creates a unique guid for the session
  * and sends a request notification to the `sshrvd` for a port1/port2 pair for this sessionId
* The sshrvd
  * finds a pair of available ports
  * opens server sockets for both of them
    * **Note**: rvd will allow just a single client socket to connect to each server socket
      * and will bridge them together
  * sends response to the client
* The client
  * receives the response notification from sshrvd (rv\_host, rv\_port\_1, rv\_port\_2)
  * and sends a request notification to the `sshnpd` including the sessionId and the rv\_host:rv\_port\_1 and a new ephemeral AES 256 key
* The daemon (`sshnpd`)
  * opens a socket to the rv\_host:rv\_port\_1 and authenticates
  * and opens a socket to its local sshd port
  * and bridges the sockets together whilst also encrypting data towards the rv\_host
  * and sends a response notification to the `sshnp` client
* The client
  * Listens on a specified port and on connection encrypts traffic received with the AES key and forward on to the rv\_host
* The client displays a message to the user that they may now `ssh -p $local_port $username@localhost`, i.e. `ssh -p 58358 gary@localhost` in the example above, and exits

This high-level flow is visualized in the diagrams below.

**NB** Requests from unauthorized client atSigns are ignored. Note that one may also completely prevent requests from any other atSigns ever even reaching the daemon by using the atProtocol's `config:allow` list feature.

> In the personal edition of noports, a daemon may have only a single authorized client atSign.
>
> The Team and Enterprise editions will allow for multiple authorized client atSigns, controlled not by the daemon but by a separate noports authorization controller process, with its own atSign.

### Overview diagram

<div data-full-width="true">

<img src="../.gitbook/assets/atPlanes.png" alt="">

</div>

### Policy Plane

At any point the `sshnpd` or the `srvd` software rather than using a local configuration to manage access rights, can forward those questions to another atSign. That atSign can in turn pass those queries to a policy engine and reflect the answer back to the asking atSign. In the example above @relay and/or @server could ask if @client is allowed to access the service. This allows decisions to be made at the Policy plane level and provides operational segregation of duties.&#x20;

### Control plane

In the following sequence diagram, atServer address lookup flows, authentication flows, key exchange flows, precise encryption mechanics and notification transmission flows are not covered in detail; those details are provided in the links provided in the "Further Details" section below.

Since the full details are provided in those other links, the `client_1 -> atServer_1 -> atServer_2 -> client_2` message flows are abbreviated to `@atSign_1 -> @atSign_2` in the sequence diagram. Thus, for example, `sshnp (@client)` encapsulates both the sshnp program and the sshnp atServer

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
        c ->> r: request two public ports from relay: {session id, nonce from client}
    else actual data flow
        c -->> cs: 
        cs -->> rs: 
        rs -->> r: 
    end
    r ->> r: Request ephemeral ports from OS
    alt
        r ->> c: ports response from relay: {session id, host1:port1, host2:port2, nonce from relay}
    else actual data flow
        r -->> rs: 
        rs -->> cs: 
        cs -->> c: 
    end

    note over c,d: Phase - Receive ping response from daemon: {list of available features}
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
    c ->> c: generate new aes encryption key & iv nonce
    alt
        c ->> d: send session request to the daemon: {host2:port2 from relay, aes stream encryption key, aes iv nonce, requested service to access (host:port), nonce from relay, nonce from client}
    else actual data flow
        c -->> cs: 
        cs -->> ds: 
        ds -->> d: 
    end
    d ->> d: Verify perimissions for client's request (based on session request info - i.e. is client allowed to connect?)
    d -x r: [TCP - A] Reverse TCP the requested service to open relay host2:port2
    d -x r: [TCP - A] Send auth string (signed json payload of: session id, nonce from relay,  nonce from client)
    r ->> r: [TCP - A] Verify auth string
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
    c -x r: [TCP - B] Send auth string (signed json payload of: session id, nonce from relay,  nonce from client)
    r ->> r: [TCP - B] Verify auth string
    note over c,d: Phase - internal traffic relays (lasts  entire duration of the session)
    par
        r -->> r: relay all traffic from [TCP - A] to [TCP - B] and vice-versa
    and
        c -->> c: relay all traffic from [TCP - A] to local socket and vice-versa
    end
    note over c,d: Phase - using the connection
    c ->> c: You connect to the local socket as if it were the remote service!
```

### Data plane

Once the interactions above have completed

* the sshnpd nor the sshnp programs are no longer involved
* there is a new sshrv process running on the device host which pipes i/o between requested server:port and $rv\_host:$rv\_port\_1
* there is a client process running on the client host which provides the local port forwarding tunnel
* User may now type "ssh -p $local\_port username@localhost"  or use a client application like and RDP client with traffic flowing
  * client ssh program <===>
    * $client\_localhost:$local\_port <===> bridged by client-side ssh tunnel to
      * $rv\_host:$rv\_port\_2 <===> bridged by sshrvd to
        * $rv\_host:$rv\_port\_1 <===> bridged by device-side sshrv to
          * $device\_host:22 <===>
            * device sshd program

![](../developer-notes/AtsignDataPlane.png)

## Further Details

In the sections above, we referred to "authentication", "sending notifications" and "receiving notifications", and we made the statement that "the payloads of the messages the programs send to each other are all end-to-end encrypted"

Here are some links to detailed diagrams covering

* [how atClients authenticate to their atServers](https://github.com/atsign-foundation/at\_protocol/blob/trunk/decisions/2023-01-pkam-per-app-and-device.md#appendix---current-flows)
* [how encrypted data is exchanged](https://github.com/atsign-foundation/at\_protocol/blob/trunk/usage-examples/how-to-exchange-encrypted-data.md) (including how keys are exchanged)
* [how notifications work](https://github.com/atsign-foundation/at\_protocol/blob/trunk/usage-examples/how-notifications-work.md)
