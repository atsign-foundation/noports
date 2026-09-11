---
icon: wrench
layout:
  width: default
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: false
  pagination:
    visible: false
  metadata:
    visible: true
  tags:
    visible: true
  actions:
    visible: true
---

# Troubleshooting

### Summary Table (Quick Reference)

| [Timeout to srvd](troubleshooting-1.md#issue-timeout-to-srvd)                                           | `TimeoutException: Connection timeout to srvd <atsign> service` | Check if relay or device Atsign exists                                      |
| ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [Daemon feature check timeout](troubleshooting-1.md#issue-daemon-feature-check-timeout)                 | `TimeoutException: Daemon feature check timed out`              | Ensure device name is correct and permissions are in place                  |
| [Keys not found after install](troubleshooting-1.md#issue-keys-not-found-after-install)                 | Keys missing after install                                      | Avoid enrolling as root; match user with SSHNPD install                     |
| [Client SSH error "chown failed error"](troubleshooting-1.md#issue-client-ssh-error-chown-failed-error) | SSH error on client                                             | Use `--permit-open` with both 127.0.0.1 and localhost; check file ownership |
| [Windows app hangs on activation](troubleshooting-1.md#issue-windows-app-hangs-on-activation)           | Stuck on “preparing for activation”                             | Update CA certificates via certutil                                         |
| [Enrollment authorization failed](troubleshooting-1.md#issue-enrollment-authorization-failed)           | `Failed to authorise enrollment`                                | Use manager keys instead of reused ones                                     |
| [SUDO\_USER is not set](troubleshooting-1.md#issue-sudo_user-is-not-set)                                | `SUDO_USER: unbound variable` or `SUDO_USER is not set`         | Log in with a regular account instead of root                               |

### ❌ Issue: Timeout to srvd

**Symptom** You receive the following error while using NoPorts: `TimeoutException: Connection timeout to srvd <atsign> service`

**Possible Causes**

* The relay Atsign (`-r`) is not running or doesn’t exist
* The device Atsign (`-t`) doesn’t exist

**Solution**

* Double-check the relay and device Atsigns for typos
* Use `sshnp --list-devices` to verify device availability

***

### ❌ Issue: Daemon Feature Check Timeout

**Symptom** `TimeoutException: Daemon feature check timed out`

**Possible Causes**

* No device is running with the specified device name (`-d`)
* You lack permission to connect to the device

**Solution**

* Confirm the device is online and registered
* Ensure your Atsign has permission to access the device

***

### ❌ Issue: Keys Not Found After Install

**Symptom** Keys are not found after device installation

**Root Cause** sshnpd was installed as root, but the enrollment was also done as root. The keys were saved to `/root/.atsign/keys/` instead of the correct user directory.

**Solution**

* Always enroll using the same user that sshnpd runs under
* Add a warning in the docs or script to prevent root-based enrollment

***

### ❌ Issue: Client SSH Error "chown failed error"&#x20;

**Symptom** Error message: `invalid daemon response: chown failed error: Operation not permitted`

**Root Cause** Raspberry Pi may behave inconsistently with `localhost` vs `127.0.0.1`, or file permissions are incorrect.

**Solution**

* Use `--permit-open="127.0.0.1:22,127.0.0.1:3389,localhost:22,localhost:3389"`
*   Ensure `~/.ssh` is owned by the correct user:

    ```
    sudo chown -R $USER:$USER ~/.ssh
    ```

***

### ❌ Issue: Windows App Hangs on Activation

**Symptom** NoPorts desktop app hangs on “preparing for activation”

**Root Cause** Outdated CA certificates on Windows 11

**Solution** Follow these steps to update root certificates:

1. Run Windows Update
2. Open Command Prompt as Administrator
3.  Run:

    ```
    certutil -generateSSTFromWU roots.sst  
    certutil -addstore -f root roots.sst
    ```
4. Verify with `certmgr.msc`
5. Repeat for Trusted Publishers if needed

***

### ❌ Issue: Enrollment Authorization Failed

**Symptom** `Failed to authorise enrollment. Client is not authorised for namespaces in the enrollment request.`

**Root Cause** You’re using a previously enrolled key for a new enrollment.

**Solution** Use the correct **manager keys** for enrollment.

***

### ❌ Issue: SUDO\_USER is not set

**Symptom**  `SUDO_USER: unbound variable` or `SUDO_USER is not set`               &#x20;

**Root Cause**&#x20;

* You are logged in as the root user.&#x20;
* No regular (non‑root) account exists on the system.

**Solution**&#x20;

* Log in with a regular account instead of root.
* Use `sudo` when elevated privileges are required.
* If you do not have a regular account, create one before running NoPorts commands.
