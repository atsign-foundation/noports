---
description: >-
  When you activate an Atsign, you are doing a handful of steps to prepare the
  Atsign for use. One of these steps is cutting a unique set of cryptographic
  keys.
icon: computer
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

# Why activate the device Atsign on the client?

The first time you activate, this set of keys that gets generated is a set of management keys. These keys have full permissions to your atServer, the personalized service which powers your Atsign.

We recommend cutting the management keys on the client for a few reasons:

1. It's extremely important that you don't lose these keys:
   1. They are less likely to get lost on your client machine than on your device.
   2. If a device is stolen you still have your management keys to recover from the theft.
2. For each device we can issue it's own set of cryptographic keys which has a few perks:
   1. This allows us to limit the permissions of those keys to the bare minimum required for NoPorts.
   2. If a device gets compromised, we can safely revoke the set of cryptographic keys associated with that device, without affecting the other devices using the same Atsign.
