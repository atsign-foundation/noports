---
description: A review of two available methods
icon: file-import
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

# Reuse your client Atsign on another machine

## Want to use your Atsign on a different machine?

You can:

A. Generate a new set of cryptographic keys (Recommended)

B. Copy the cryptographic keys from the machine where it's been activated in the past (Not recommended)

### **Option A) Generate a new set of cryptographic keys (Recommended)**

To generate a new set of cryptographic keys, there are three main steps. They occur from two different machines, so pay careful attention to which machine you perform each step on.

"Old machine" is the machine that has the **original** set of cryptographic keys that were generated. "New machine" is the device you want the new set of cryptographic keys on. These new keys will have restricted permissions that only work with NoPorts, and cannot be used for generating other keys.

1. \[Old machine] Generate a Passcode&#x20;
2. \[New machine] Enroll the new key pair (send a request for keys from the new machine)
3. \[Old machine] Approve the request

**For detailed instructions, follow this guide:**

{% content-ref url="generate-a-new-set-of-cryptographic-keys.md" %}
[generate-a-new-set-of-cryptographic-keys.md](generate-a-new-set-of-cryptographic-keys.md)
{% endcontent-ref %}

### **Option B) Copy the cryptographic keys from the machine where it's been activated in the past (Not recommended)**

* The Atsign keys file will be located at `~/.atsign/keys/` directory with a filename that will include the Atsign. Copy this file from your other machine to the same location on the machine that you are installing SSH No Ports on, using `scp` or similar.

Why don't we recommend this approach?

> When you use method A, it creates a new set of cryptographic keys. These keys can be disabled individually, which means if a device's keys are compromised, you can disable those keys without affecting your other devices.
