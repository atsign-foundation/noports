---
description: Common questions about NoPorts
icon: comments-question-check
layout:
  width: default
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: false
  metadata:
    visible: true
  tags:
    visible: true
  actions:
    visible: true
---

# Frequently Asked Questions

### How NoPorts Works

<details>

<summary>How is NoPorts different from Tailscale and Ngrok?</summary>

Everything is in your control. There are no Web Interfaces or centralized control by us, as we never want to be an attack surface for your infrastructure. NoPorts does not connect "networks," but provides on demand encrypted TCP connectivity to existing SSH daemons.

NoPorts is focused on providing end-to-end encrypted and authenticated access to a remote ssh daemon, bound to localhost.

NoPorts does not require any open (listening) ports on external interfaces, so there is no network attack surface on devices using NoPorts.

NoPorts provide relays like Ngrok, but connections are authenticated then connected. Once connected, the connection is encrypted with ephemeral (AES256) keys that the relay never has or needs.

NoPorts abstracts away the TCP/IP layer, so whilst IP address on the client or device may change, the command you use never does.

</details>

<details>

<summary>Why is additional encryption needed when SSH provides its own encryption?</summary>

Additional encryption protects the request and rendezvous information (on the relay) that is sent from the client device to the remote device’s atServer and ultimately to the client. Without encryption, this information could be intercepted, and a bad actor could meet the client device at the relay This is precisely how the [https://terrapin-attack.com/](https://terrapin-attack.com/) works. Using NoPorts mitigates any man-in-the-middle attacks like Terrapin.

</details>

<details>

<summary>Is sshnp a reverse SSH tunnel?</summary>

sshnp is similar to a reverse tunnel in that it has the remote device start an outbound SSH session. What makes sshnp better than a reverse SSH tunnel is that you don’t need access to the device to initiate it. This means you don’t need to leave open ports when not in use (i.e. there are no network attack surfaces).

</details>

<details>

<summary>The TCP layer is not taken out in your architecture. Does your protocol run over and above it?</summary>

Yes. NoPorts uses the atProtocol which runs on TCP. In order for NoPorts to reach the device, the device must have an IP address. However, it does not need to be a static IP address, and NoPorts doesn't even need to know what the IP address is. So, even though it runs over TCP/IP, it does away with all the pain of finding and managing IP addresses.

</details>

### **Relay Service and Network Behavior**

<details>

<summary>Is the relay necessary?</summary>

The relay ensures that connections from client and server are always outbound, removing the need for listening ports, firewall rules, and network attack surfaces on devices.

NoPorts uses TCP sockets to communicate. "Hole punching" can work sometimes, but we decided to never do that. Using the relay, you know that NoPorts will always work and is friendly to both network admins and firewall rules.

For most customers our relay service is robust and placed regionally. The relay code is open and the binaries are part of the distribution, so you can place your own relay where it makes sense for your network.

</details>

<details>

<summary>If a bad actor takes down the relay, does the tool fail?</summary>

In the unlikely event that a bad actor takes down an relay, the tool will indeed fail. Fortunately, we run multiple relays, so if one is down or unavailable, you can easily switch to another.

</details>

<details>

<summary>Since the device and the client need to connect out to the relays, do I need to open ports on my firewall for them to connect out to the relay?</summary>

You do not need to open any inbound ports to connect out to the relay. However, the outbound traffic to the relay server does need to be open. Outbound access is, in most situations, automatically allowed so things just work. If you work in a location where outbound access is also controlled, then please contact us as we have options for for your IT team.

</details>

<details>

<summary>Who pays the ingress &#x26; egress costs to the relay?</summary>

These costs are included in the NoPorts subscription.

</details>

### Security and Access Control

<details>

<summary>How do I close port 22?</summary>

To close port 22, edit `/etc/ssh/sshd_config` remove any lines containing `ListenAddress` and then add `ListenAddress localhost` on a new line. Then restart your sshd service (this varies by operating system, a quick web search will help you figure how to do it for your device).

{% hint style="info" %}
Additional notes for advanced users
{% endhint %}

You may also replace `localhost` with the ipv4 (`127.0.0.1`) or ipv6 (`::1`) loopback address. However beware! All NoPorts tech defaults to doing lookups for localhost. If your system has both configured in `/etc/hosts` then NoPorts may resolve to the wrong address for which sshd is configured for.

</details>

<details>

<summary>What Security Group rules are needed for CSP (Cloud Service Provider) deployments, for both data and control plane traffic?</summary>

Security groups only need to allow outbound internet access.

</details>

<details>

<summary>What npt or iptables rules are needed for non-CSP deployments, for both data and control plane traffic?</summary>

Only outbound internet access via NAT/CGNAT is required.

</details>

<details>

<summary>If the control plane is unreachable, what fallback or break-glass contingency is available?</summary>

Break-glass options include console access or, if you trust the local network, leaving sshd listening on an internal interface. We’ve designed the system to minimize lockout risks. In production use, lockouts have been extremely rare, but when they happen it’s normally inadvertent blocking of outbound TCP connections being the issue.

</details>

<details>

<summary>Why do I see man-in-the-middle warnings when connecting to my NoPorts devices?</summary>

These warnings occur because each time you SSH into a machine, you’re connecting to localhost on a random port number. If you later use the same localhost and port number to connect to a different machine, this may be interpreted as a potential security risk, triggering a man-in-the-middle warning—even if the system is not compromised.

</details>

<details>

<summary>How can I prevent these warnings?</summary>

You can address this issue with one of two approaches:

1. Assign a Fixed Local Port – By default, each session is assigned a random local port. To prevent mismatches, you can manually specify a static local port for each machine using the -l \<port number> option.
2. Trust NoPorts for Keys and Adjust SSH Config – You can update your SSH configuration (\~/.ssh/config) to disable strict host key checking for localhost sessions:

```
Host 127.0.0.1
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    IdentityFile ~/.ssh/GitHub_rsa
    LogLevel QUIET
```

</details>

<details>

<summary>Why do I see extra entries in my ~/.ssh/authorized_keys file, and can I remove them?</summary>

You may notice additional entries appearing in your \~/.ssh/authorized\_keys file. These entries were originally included for backward compatibility and were used for ephemeral SSH keys in reverse SSH. In most cases, they are not actively used and may persist even after a session ends.

You can safely delete these extra entries, as they do not impact functionality unless specifically needed. We will be removing them from the code soon, but in the meantime, any leftover entries can be manually cleaned up without affecting your setup.

</details>

### **Component Deployment and Operation**&#x20;

<details>

<summary>How are the NoPorts Tunnel, NoPorts daemon, and the NoPorts TCP relay service deployed?</summary>

Deployment is done using curl and tar directly from our GitHub repo. You can do this manually or using a provided bash script that does the hard work for you. Refer to the  [Installation](https://docs.noports.com/installation) documentation for detailed instructions.&#x20;

</details>

<details>

<summary>How are these components started and managed?</summary>

Systemd is the default service manager. Alternatives like cron and TMUX also work, but Systemd is recommended for standard deployments.

</details>

<details>

<summary>How are these components patched or updated?</summary>

To update, re-run the installation script. You can verify the currently deployed versions using the --list-devices option with with the sshnp command.

</details>

<details>

<summary>Do these components require root privileges to run?</summary>

No, these components must not run as root.

</details>

<details>

<summary>How does SELinux affect these components?</summary>

SELinux does not affect them, as these components operate in user space. That said, they require permission to open ports on the localhost interface and establish outbound TCP connections.

</details>

<details>

<summary>During the Startup Phase, the relay and npt handshake with their respective Atsign services. Does npt on the client also handshake with its Atsign service once at boot, or on each SSH initiation?</summary>

The sshnpd maintains a persistent connection to its atServer. Other interactions are event-driven.

</details>

<details>

<summary>Does the bridging between ingress/egress ports within np services require the same NIC, or can it occur across different NICs?</summary>

This involves standard TCP connections, so normal connectivity rules apply. No layer 2 bridging is performed; only TCP connections are established in user space.

</details>

### **Scripting and Remote Command Execution**

<details>

<summary>Does NoPorts support scripting and remote command execution?</summary>

Yes, NoPorts allows for scripting and remote command execution, similar to standard SSH. While the -x option in sshnp does not directly execute commands on the remote machine, you can still achieve this using the following format:

`$(sshnp -f @bob -t @ssh_1 -r @rv_am -d iot_device01 -x) hostname`

</details>

<details>

<summary>What are the requirements for executing remote commands via NoPorts?</summary>

For this method to work, you need a clean login, meaning SSH keys must be properly configured and in place for sshnp. Ensuring your SSH setup supports key-based authentication will allow commands to run on the remote machine.

</details>

### **Usage and Protocol Support**

<details>

<summary>So, you can SSH without any open ports... what about RDP?</summary>

You can use NoPorts Tunnel for RDP. [This guide](../use-cases/rdp.md) demonstrates how.&#x20;

</details>

### Did we miss something?

If you have a question that needs answering, please do one of the following:

* Create a new [GitHub issue](https://github.com/atsign-foundation/noports/issues/new/choose)
* Join [our discord](https://discord.atsign.com) and post to our `📑｜forum` channel
* [Contact support via email](mailto:support@noports.com)
