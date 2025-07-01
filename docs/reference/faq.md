---
description: Common questions about NoPorts
icon: comments-question-check
---

# Frequently Asked Questions

## **How is NoPorts different from Tailscale and Ngrok?**

Everything is in your control. There are no Web Interfaces or centralized control by us, as we never want to be an attack surface for your infrastructure. NoPorts does not connect "networks," but provides on demand encrypted TCP connectivity to existing SSH daemons.

NoPorts is focused on providing end-to-end encrypted and authenticated access to a remote ssh daemon, bound to localhost.

NoPorts does not require any open (listening) ports on external interfaces, so there is no network attack surface on devices using NoPorts.

NoPorts provide relays like Ngrok, but connections are authenticated then connected. Once connected, the connection is encrypted with ephemeral (AES256) keys that the relay never has or needs.

NoPorts abstracts away the TCP/IP layer, so whilst IP address on the client or device may change, the command you use never does.

## **Is the relay necessary?**

The relay ensures that connections from client and server are always outbound, removing the need for listening ports, firewall rules, and network attack surfaces on devices.

NoPorts uses TCP sockets to communicate. "Hole punching" can work sometimes, but we decided to never do that. Using the relay, you know that NoPorts will always work and is friendly to both network admins and firewall rules.

For most customers our relay service is robust and placed regionally. The relay code is open and the binaries are part of the distribution, so you can place your own relay where it makes sense for your network.

## **If a bad actor takes down the relay, does the tool fail?**

In the unlikely event that a bad actor takes down an relay, the tool will indeed fail. Fortunately, we run multiple relays, so if one is down or unavailable, you can easily switch to another.

## **Since the device and the client need to connect out to the relays, do I need to open ports on my firewall for them to connect out to the relay?**

You do not need to open any inbound ports to connect out to the relay. However, the outbound traffic to the relay server does need to be open. Outbound access is, in most situations, automatically allowed so things just work. If you work in a location where outbound access is also controlled, then please contact us as we have options for for your IT team.

## **Who pays the ingress & egress costs to the relay?**

These costs are included in the NoPorts subscription.

## **Why is additional encryption needed when SSH provides its own encryption?**

Additional encryption protects the request and rendezvous information (on the relay) that is sent from the client device to the remote device’s atServer and ultimately to the client. Without encryption, this information could be intercepted, and a bad actor could meet the client device at the relay This is precisely how the [https://terrapin-attack.com/](https://terrapin-attack.com/) works. Using NoPorts mitigates any man-in-the-middle attacks like Terrapin.

## **Is sshnp a reverse SSH tunnel?**

sshnp is similar to a reverse tunnel in that it has the remote device start an outbound SSH session. What makes sshnp better than a reverse SSH tunnel is that you don’t need access to the device to initiate it. This means you don’t need to leave open ports when not in use (i.e. there are no network attack surfaces).

## **The TCP layer is not taken out in your architecture. Does your protocol run over and above it?**

Yes. NoPorts uses the atProtocol which runs on TCP. In order for NoPorts to reach the device, the device must have an IP address. However, it does not need to be a static IP address, and NoPorts doesn't even need to know what the IP address is. So, even though it runs over TCP/IP, it does away with all the pain of finding and managing IP addresses.

## **So, you can SSH without any open ports... what about RDP?**

You can use NoPorts Tunnel for RDP. [This guide](../use-cases/rdp.md) demonstrates how.&#x20;

## How do I close port 22?

To close port 22, edit `/etc/ssh/sshd_config` remove any lines containing `ListenAddress` and then add `ListenAddress localhost` on a new line. Then restart your sshd service (this varies by operating system, a quick web search will help you figure how to do it for your device).

<details>

<summary>Additional notes for advanced users</summary>

You may also replace `localhost` with the ipv4 (`127.0.0.1`) or ipv6 (`::1`) loopback address. However beware! All NoPorts tech defaults to doing lookups for localhost. If your system has both configured in `/etc/hosts` then NoPorts may resolve to the wrong address for which sshd is configured for.

</details>

## What should I enter when creating a profile in the NoPorts desktop application?

A profile in NoPorts is a collection of saved settings that lets you quickly connect to your remote device. When setting one up, you’ll need to provide a few details—here are some examples of what you might enter:

### **RDP Example**

**Profile Name** - Camera RDP                                     &#x20;

**Device atSign** - @purple66\_device                       **Device Name** - homecam

**Relay** - rv\_am

**Local Port** - 33389                  **Remote Host** - localhost                **Remote Port** - 3389

### **SFTP Example**

**Profile Name** - VM SFTP                                     &#x20;

**Device atSign** - @purple66\_device                       **Device Name** - windowsvm

**Relay** - rv\_am

**Local Port** - 2222                  **Remote Host** - localhost                **Remote Port** - 22

## Did we miss something?

If you have a question that needs answering, please do one of the following:

* Create a new [GitHub issue](https://github.com/atsign-foundation/noports/issues/new/choose)
* Join [our discord](https://discord.atsign.com) and post to our `📑｜forum` channel
* [Contact support via email](mailto:support@noports.com)
