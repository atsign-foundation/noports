---
description: >-
  SSH No Ports uses Atsign’s end-to-end encrypted control plane to initiate SSH
  connections without opening ports on either of your devices.
icon: magnifying-glass
---

# How It Works

## **Atsign’s Core Technology (a.k.a. Control Plane)**

1. **Addressability**\
   Atsign’s core technology uses identifiers which replace the need to manage IP addresses. If you remember the atSign (Atsign’s version of an address), you can look up the IP address and port in the atDirectory which manages this information for you.
2. **Reachability**\
   **‍**Atsign’s core technology provides each device with its own microservice which makes it reachable from anywhere on the Internet.
3. **No open ports (no network attack surface) on the device**\
   Connections are always made from the device to the microservice, meaning that no ports ever need to be opened on devices using this technology.
4. **End-to-end encrypted**\
   Information is automatically encrypted on the edge devices before it is sent over Atsign’s control plane.
5. **Zero Trust**\
   Atsign’s technology is designed so that cryptographic keys are only stored on the edge device. No third party or intermediary ever possesses the decryption keys which are required to access the information. You don’t need to trust any of the microservices, because they never see information in the clear.

## **How SSH No Ports uses Atsign’s Control Plane**

{% embed url="https://player.vimeo.com/video/859419053?app_id=122963&referrer=https://www.noports.com/" %}
**How SSH No Ports Works** (_This video doesn't include the new SR authentication and traffic encryption features yet, we will release an updated video soon!_)&#x20;
{% endembed %}

1. Alice wants to securely connect to her remote device, @alice\_device.
2. To initiate this, Alice’s client, @alice\_client, will first select a socket rendezvous, or SR for short.
3. The SR will issue two connection ports to @alice\_client by providing the host address and two port numbers. This is done through Atsign’s control plane, and the information is end-to-end encrypted.
4. Next, @alice\_client requests a connection to @alice\_device and shares one port from the SR.
5. The device, @alice\_device, generates a new ephemeral SSH key pair for the session.
6. @alice\_device automatically sends the ephemeral SSH private key to @alice\_client.
7. @alice\_device will then connect to the SR using Atsign's SR client. The SR client authenticates to the SR, then forwards @alice\_device's SSHD port to the SR. The SR client ensures that all traffic sent to the SR is encrypted, and it also decrypts all traffic from the SR. &#x20;
8. @alice\_client can now also connect and authenticate to the SR using the SR client. This side also encrypts all traffic to the SR, and decrypts all traffic from the SR, ensuring that the connection is fully end-to-end encrypted between @alice\_client and @alice\_device.
9. The SR connects both ports issued to @alice ensuring that traffic sent between the connection is able to reach the other side.
10. An SSH tunnel from @alice\_client is created over the connected tunnel through the SR to @alice\_device.
11. This tunnel forwards an ephemeral port on @alice\_client’s localhost to @alice\_device’s SSHD port.
12. Now the connection is ready! The application will provide an SSH command which can be used to connect over this tunnel.
13. When running the command, Alice will be able to SSH connect to @alice\_device!
14. Alice has successfully connected to her remote device, @alice\_device.



