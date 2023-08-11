# What's happening under the hood?

**Note**: This document describes version 3.5.0 or greater; v3.5.0 will be
released mid-August 2023

## Overview
There are three atSigns involved - one for each of
- the noports daemon program (`sshnpd`) which runs on the device you want to 
  ssh to
- the noports client program (`sshnp`) which you run on the device you want to 
  ssh from
- the noports tcp rendezvous program (`sshrvd`)

The programs communicate via the atProtocol and the atClient SDKs; as a 
result, the payloads of the messages the programs send to each other are all 
end-to-end encrypted.

In brief
- The client (`sshnp`) creates a unique guid for the session
  - and sends a request notification to the `sshrvd` for a port1/port2 pair
    for this sessionId
- The sshrvd
  - finds a pair of available ports
  - opens server sockets for both of them
    - **Note**: rvd will allow just a single client socket to connect to each 
      server socket
      - and will bridge them together once the rvd has received the 
      sessionId on both sockets
  - sends response to the client
- The client
  - receives the response notification from sshrvd (rv_host, rv_port_1, 
    rv_port_2)
  - and sends a request notification to the `sshnpd` including the sessionId 
    and the rv_host:rv_port_1
- The daemon (`sshnpd`)
  - opens a socket to the rv_host:rv_port_1
  - and writes the sessionId on it
  - and opens a socket to its local sshd port
  - and bridges the sockets together
  - and sends a response notification to the `sshnp` client
- The client
  - binds a local server socket
  - and opens a socket to the rv_host:rv_port_2
  - and writes the sessionId on it
  - and bridges the sockets together
- The client displays a message to the user that they may now
  `ssh -p $local_port $username@localhost`, and exits

This high-level flow is visualized in the diagrams below.

**NB** Requests from unauthorized client atSigns are ignored. Note that one
may also completely prevent requests from any other atSigns ever even
reaching the daemon by using the atProtocol's `config:allow` list feature.
> In the personal edition of noports, a daemon may have only a single
> authorized client atSign.
>
> The Team and Enterprise editions will allow for multiple authorized client
> atSigns, controlled not by the daemon but by a separate noports
> authorization controller process, with its own atSign.

### Overview diagram
![](overview.png)

### Control plane
In the following sequence diagram, atServer address lookup flows, 
authentication flows, key exchange flows, precise encryption mechanics and 
notification transmission flows are not covered in detail; those details are 
provided in the links provided in the "Further Details" section below.

Since the full details are provided in those other links, the 
`client_1 -> atServer_1 -> atServer_2 -> client_2`
message flows are abbreviated to `@atSign_1 -> @atSign_2` in the 
sequence diagram. Thus, for example, `sshnp (@client)` encapsulates both the 
sshnp program and the sshnp atServer

```mermaid
sequenceDiagram
    participant C as sshnp (@client)
    participant R as sshrvd (@rv)
    participant D as sshnpd (@device)

    note over R,D: service startups
    D->D: Authentication
    D->D: Start monitor <br> (notification listener)
    
    R->R: Authentication
    R->R: Start monitor <br> (notification listener)

    note left of C: user runs the sshnp program
    C->C: Authentication
    C->C: Start monitor <br> (notification listener)
    
    note left of C: sshnp sends session request <br> notification to sshrvd
    C->C: Create sessionId guid to send to @rv
    C->C: Encrypt message to send to @rv
    C->>R: Send notification to @rv <br> requesting host and port
    
    R->R: Decrypt request payload
    R->R: Find two unused ports
    R->R: Create an isolate <br> which creates server sockets <br> on the ports, waits for connections, <br> and joins their i/o streams <br> ONCE BOTH CONNECTIONS have sent the sessionId
    R->R: Create and encrypt <br> response message containing <br> sessionId, host, port_1, port_2
    R->>C: Send response notification <br> to @client
    
    C->C: Create and encrypt request message <br> to send to @device (sessionId, host, port1)
    C->>D: Send request to sshnpd
    D->>D: SPAWN an sshrv process
    D->>R: (Spawned) Open socket $npd_to_rv to host:port_1
    D->>R: (Spawned) write "$sessionId\n" to $npd_to_rv socket
    D->>D: (Spawned) Open socket $npd_to_sshd to localhost:22
    D->>D: (Spawned) Join $npd_to_rv and $npd_to_sshd <br> i/o streams, and vice versa
    D->>C: Send "connected" response notification if spawned successfully
    C->>C: Find an available $local_port
    C->>C: SPAWN an sshrv process
    C->>R: (Spawned) Open socket $npc_to_rv to host:port_2
    C->>R: (Spawned) write "$sessionId\n" to $npc_to_rv socket
    C->>C: (Spawned) Create server socket $npc_local listening on $local_port
    C->>C: (Spawned) Join $npc_local and $npc_to_rv  <br> i/o streams, and vice versa
    C->>C: If spawned successfully, Write to stdout: "ssh -p $local_port $username@localhost"
```

### Data plane
Once the interactions above have completed
- the sshnpd nor the sshnp programs are no longer involved
- there is a new sshrv process running on the device host which pipes i/o 
  between device port 22 and $rv_host:$rv_port_1 
- there is a new sshrv process running on the client host which pipes i/o
  between client port $local_port and $rv_host:$rv_port_2
- User may now type "ssh -p $local_port username@localhost" with traffic flowing 
  - client ssh program <===>
    - $client_localhost:$local_port <===> bridged by client-side sshrv to
      - $rv_host:$rv_port_2 <===> bridged by sshrvd to
        - $rv_host:$rv_port_1 <===> bridged by device-side sshrv to
          - $device_host:22 <===>
            - device sshd program

```mermaid
sequenceDiagram
    participant ssh
    participant clp as client local port
    participant rvp1 as rvd port 1
    participant rvp2 as rvd port 2
    participant dp22 as device port 22
    participant sshd
    
    note over ssh,clp: client host
    note over rvp1, rvp2: rvd host
    note over dp22, sshd: device host
    
    note over clp, rvp1: Bridged by <br> client sshrv
    note over rvp1, rvp2: Bridged by <br> rvd
    note over rvp2, dp22: Bridged by <br> device sshrv
    
    ssh ->> sshd: packets from ssh to sshd
    sshd ->> ssh: packets from sshd to ssh
```

## Further Details
In the sections above, we referred to "authentication", "sending 
notifications" and "receiving notifications", and we made the statement that
"the payloads of the messages the programs send to each other are all
end-to-end encrypted"

Here are some links to detailed diagrams covering
- [how atClients authenticate to their atServers](https://github.com/atsign-foundation/at_protocol/blob/trunk/decisions/2023-01-pkam-per-app-and-device.md#appendix---current-flows)
- [how encrypted data is exchanged](https://github.com/atsign-foundation/at_protocol/blob/trunk/usage-examples/how-to-exchange-encrypted-data.md) (including how keys are exchanged)
- [how notifications work](https://github.com/atsign-foundation/at_protocol/blob/trunk/usage-examples/how-notifications-work.md)
