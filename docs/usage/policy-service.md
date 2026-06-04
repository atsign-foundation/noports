---
icon: users-rectangle
---

# Policy Service

This page describes using the policy service

### Policy Service Status

The Policy Service must remain running at all times to listen for incoming requests from daemons querying the policy server.&#x20;

### Policy Roles

In the context of the Policy Service, a **role** defines a set of access permissions that determine which Atsigns can interact with specific devices or groups of devices through NoPorts.

When creating a role you will need to enter the following information:

|                    |                                                                                                                               |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| **Name**           | The role's name                                                                                                               |
| **Description**    | The role's description                                                                                                        |
| **Device Atsigns** | The device Atsign(s) to which the policy role will be applied                                                                 |
| **Devices**        | The device name(s) associated with the device Atsign along with the local ports that NoPorts has permitted for secure access  |
| **Device Groups**  | The device name(s) associated with a group of devices along with the local ports that NoPorts has permitted for secure access |
| **User Atsigns**   | The Atsigns that will have access to the  devices and/or device groups                                                        |

After a role is created and saved, the Atsigns listed in the User Atsigns section will be able to connect to the designated ports and interact with the specified devices using the assigned device Atsigns.

If using device groups, be sure the specify the device group name when running the NoPorts Daemon on your device. For example:

```bash
./sshnpd -a @<YOUR DEVICE ATSIGN> -p @<YOUR POLICY ATSIGN> --device-group <DEVICE GROUP>
```

