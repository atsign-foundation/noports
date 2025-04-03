# Socket Connector Design

Date: 04/03/2025

Timeline:

- Implementation started end of Q1 2025
- To be completed early-mid Q2 of 2025

## Table of Contents

1. Problems and Goals  
  a. Problems and Challenges we are trying to solve  
  b. Future proofing design for foreseeable enhancements  
  c. Additional goals  
2. Overview of Redesign  
  a. Maintaining Backwards Compatibility  
  b. Supporting New Foreseeable Functionality  
  c. Minimizing Abstraction Overhead  
3. Channels  
  a. Channel IO  
  b. Channel Sinks  
  c. Channel Transformers  
  d. Channel Authenticators  
  e. Channel Concurrency  
4. Sessions  
  a. Single Session Type  
  b. Stacking Session Type  
  c. Control Session Type  
5. Why go through all of this effort?  

## Problems and Goals

### Problems and Challenges we are trying to solve

- Stability and reliable HTTPs support with C srv
- Mitigate replay attacks to srvd
- Improve bandwidth for highly sensitive environments
- Merged srvd's socket connector into srv

### Future proofing design for foreseeable enhancements

- Supporting alternative auth methods
- Supporting alternative encryption algorithms
- Supporting new control socket features
- Enable multiplexing sessions over a single port on the relay
- Support the spawning of relay sessions using an external binary
- Enable UDP support

### Additional Goals

- Minimize dependencies
  - No atclient: C atclient is subject to breaking changes, and has still room
    for improvements to memory management & test coverage

## Overview of Redesign

The overall system design of srv needs to support many different composable
configuration options in order to support changing needs as the system grows.
This means that some abstractions need to be introduced with three major
considerations:

1. The existing functionality and modes of socket connector remain fully
   backwards compatible
2. New foreseeable functionality has a clear place for being introduced
3. Abstraction overhead must be minimal, or ideally, close to none

### Maintaining Backwards Compatibility

In order to achieve the first goal of maintaining backwards compatibility, we
must avoid changing any of the existing mandatory arguments, and create aliases
to any optional arguments we change. Since functionality is preserved, this
change is relatively trivial.

### Supporting New Foreseeable Functionality

For new foreseeable functionality, in addition to basic socket management
there are currently three features to consider: data encryption / decryption,
authentication to the relay service, and writing to / reading from sockets.

### Minimizing Abstraction Overhead

As for minimizing abstraction overhead, the two major things to consider here
are: how the data flows - abstractions should not cause data to be moved
otherwise unnecessarily, and concurrency - how can be use asynchronous code to
our advantage. Note that thread management also has a baseline overhead, so
to truly perfect this, we would have to do experimentation, but just avoiding
going overboard should be sufficient for the initial redesign.

## Channels

Channels are the first abstraction to consider here. A channel represents a
bi-directional channel for communication. Within a channel there are two main
sub-abstractions: IO and Sinks.

IO represents Input/Output, a place to read from or write to.

Sinks represent one direction of communication, with a sink, we may fill from
one IO and drain it to the other IO, the other sink works in the opposite
direction.

### Channel IO

There are two types of channel IO that present themselves as immediately useful
to us: TCP sockets, and in-memory streams. TCP sockets are used by traditional
NoPorts, and in-memory streams is useful when we want to embed the socket
connector into an application directly.

There are more types to of channel IO to consider below.

#### Directional Typing

- Inbound IO like tcp bind sockets, which accept a connection to be used
- Outbound IO like tcp clients, which make connections to bind sockets

#### Remote IO vs Local IO

There is a "remote" side and a "local" side. This is just a naming convention,
but in most cases, the names will be relevant to purpose. The only exception is
srvd, where "local" will represent the NoPorts client connection and "remote"
will represent the NoPorts daemon connection.

For NoPorts client and daemon, remote and local are already relevant names.
They both need to authenticate and encrypt to the remote, and decrypt from the
remote.

### Channel Sinks

Channel sinks are responsible for managing the intermediary data representation
between IO and the in-memory representation required for the socket connector
to function. The general lifecycle of a sink is to:

1. Read in from IO, filling the sink
2. Transform the data in-memory
3. Drain the sink, writing out to the other IO

### Channel Transformers

As mentioned under sink, sometimes we need to transform the data, for example,
with NoPorts we need to AES CTR encrypt/decrypt data. The transformer
abstraction provides the interface for doing so, regardless of how the
transformer actually implements this. In the future, if other encryption
algorithms are requested, this will be as simple as changing the transformer
options upon execution of the binary.

### Channel Authenticators

Similarly to transformers, we currently use a simple payload auth string.
The authenticator is invoked at the start of a new IO connection. However,
with the goal of merging srvd functionality into this binary, the authenticator
implementation will need to support both authenticating to something else, as
well as verifying authentication from something else.

Note: one of the benefits of merging srvd binaries into NoPorts is so that the
socket connector runs as a separate process. This does two things:

1. Per-process file descriptor limits are applied per session, rather than
   globally across all relay sessions.
2. In the event of a session crash, other sessions and the relay itself remain
   largely unaffected

### Channel Concurrency

Concurrency is the major consideration here, the simplest way to reduce
difficulties while programming, is to introduce ring buffers for the ability
to have lock free reading and writing within sink memory. This should be enough
to run sinks concurrently, as well as reading and writing within sinks
concurrently.

## Sessions

Sessions are the construct that may contain one or more channels based on the
configuration of the socket connector. They are the abstraction for determining
how the socket connector will run and manage sockets.

### Single Session Type

The single session type has a single channel, it creates the channel on
initialization and has no way to form new channels.

### Stacking Session Type

The stacking session type must have at least one bound socket (or equivalent
inbound IO type). Upon connection to the stacking session's bound socket, the
other IO will either be created if it is an outbound connection, or wait for
an inbound connection to link with on the other side.

### Control Session Type

The control session creates a special Channel IO on the remote side used for
orchestration, it is similar to the stacking session, except that it uses the
special channel IO to orchestrate channels across two different machines. Like
the stacking session type, one of the two control sessions instances must have
an inbound channel IO on the local side to initiate the creation of a new
channel.

## Why go through all of this effort?

Put simply, when we made the decision to uptake NoPorts daemon in C99 for
broader compatibility, srv was one of the first pieces to be completed. Since
then, the team's skills have grown, and we can very easily improve both
stability and performance of it. As the main author of the original code, I am
comfortable saying: "It's time to throw away the original implementation."
