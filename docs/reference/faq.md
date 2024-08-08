---
icon: comments-question-check
---

# FAQ

## **How is SSH No Ports different from Tailscale and ngrok?**

Everything is in your control. There are no Web Interfaces or centralized control by us, as we never want to be an attack surface for your infrastructure. SSH No ports does not connect "networks," but provides on demand encrypted TCP connectivity to existing SSH daemons.

SSH No Ports is focused on providing end-to-end encrypted and authenticated access to a remote ssh daemon, bound to localhost.

SSH No Ports does not require any open (listening) ports on external interfaces, so there is no network attack surface on devices using SSH No Ports.

SSH No ports provide socket rendezvous points like Ngrok, but connections are authenticated then connected. Once connected, the connection is encrypted with ephemeral (AES256) keys that the socket rendezvous point never has or needs.

SSH No ports abstracts away the TCP/IP layer, so whilst IP address on the client or device may change, the command you use never does.

## **Is the socket rendezvous (SR) necessary?**

The SR ensures that connections from client and server are always outbound, removing the need for listening ports, firewall rules, and network attack surfurces on devices.

SSH No ports uses TCP sockets to communicate. "Hole punching" can work sometimes, but we decided to never do that. Using the socket rendezvous, you know that SSH No Ports will always work and is friendly to both network admins and firewall rules.

For most customers our SR service is robust and placed regionally. The SR code is open and the binaries are part of the distribution, so you can place your own SR where it makes sense for your network.

## **If a bad actor takes down the socket rendezvous (SR), does the tool fail?**

In the unlikely event that a bad actor takes down an SR, the tool will indeed fail. Fortunately, we run multiple SRs, so if one is down or unavailable, you can easily switch to another.

## **Since the device and the client need to connect out to the socket rendezvous (SR), do I need to open ports on my firewall for them to connect out to the SR?**

You do not need to open any inbound ports to connect out to the SR. However, the outbound traffic to the SR server does need to be open. Outbound access is, in most situations, automatically allowed so things just work. If you work in a location where outbound access is also controlled, then please contact us as we have options for for your IT team.

## **Who pays the ingress & egress costs to the socket rendezvous (SR)?**

These costs are included in the SSH No Ports subscription.

## **Why is additional encryption needed when SSH provides its own encryption?**

Additional encryption protects the request and rendezvous information (on the SR) that is sent from the client device to the remote device’s atServer and ultimately to the client. Without encryption, this information could be intercepted, and a bad actor could meet the client device at the socket rendezvous. This is precisely how the [https://terrapin-attack.com/](https://terrapin-attack.com/) works. Using SSH No Ports mitigates any man-in-the-middle attacks like Terrapin.

## **Is SSH No Ports a reverse SSH tunnel?**

SSH No Ports is similar to a reverse tunnel in that it has the remote device start an outbound SSH session. What makes SSH No Ports better than a reverse SSH tunnel is that you don’t need access to the device to initiate it. This means you don’t need to leave open ports when not in use (i.e. there are no network attack surfaces).

## **The TCP layer is not taken out in your architecture. Does your protocol run over and above it?**

Yes. SSH No Ports uses the atProtocol which runs on TCP. In order for SSH No Ports to reach the device, the device must have an IP address. However, it does not need to be a static IP address, and SSH No Ports doesn't even need to know what the IP address is. So, even though it runs over TCP/IP, it does away with all the pain of finding and managing IP addresses.

## **So, you can SSH without any open ports...what about RDP?**

You can use SSH No Ports (as it is) to RDP right now! While it is still not its own "RDP No Ports" product, you can run an SSH No Ports session in the background and append the -L SSH flag using the -o sshnp flag to forward the local RDP port 3389 on your desktop to a local port on your client. Here's a [quick video explainer](https://www.youtube.com/watch?v=G3rRBHdwHvI) for more details. We are working on other No Ports products that will not be reliant on SSH.

## How do I close port 22?

To close port 22, edit `/etc/ssh/sshd_config` remove any lines containing `ListenAddress` and then add `ListenAddress localhost` on a new line. Then restart your sshd service (this varies by operating system, a quick web search will help you figure how to do it for your device).

<details>

<summary>Additional notes for advanced users</summary>

You may also replace `localhost` with the ipv4 (`127.0.0.1`) or ipv6 (`::1`) loopback address. However beware! All No Ports tech defaults to doing lookups for localhost. If your system has both configured in `/etc/hosts` then SSH No Ports may resolve to the wrong address for which sshd is configured for.

</details>

## Did we miss something?

If you have a question that needs answering, please do one of the following:

* Create a new [GitHub issue](https://github.com/atsign-foundation/noports/issues/new/choose)
* Join [our discord](https://discord.atsign.com) and post to our `📑｜forum` channel
* [Contact support via email](mailto:support@noports.com)
