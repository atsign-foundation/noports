---
icon: key
description: Using ssh-keygen
---

# How to generate SSH keys

SSH uses keys to authenticate as well as having a fallback of using passwords, but using keys is easier and more secure than "mypassword!". If you already are a seasoned user of SSH then you might have keys already, but if not, then on the client machine you can create a key pair using ssh-keygen.

Example ssh-keygen command to create SSH Key Pair

```
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519
```

##
