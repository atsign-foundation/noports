---
description: np.sh - The quick run script
icon: list-ol
---

# Quick SSH picker script

If you installed the noports client using our `universal.sh` script, you may have noticed that it installed an additional script called `np.sh`.

This script was installed to make it slightly easier to connect to all of your devices using noports, if you are good with scripting or already have a preferred way to use noports, feel free to delete, modify or ignore this script entirely.

{% hint style="danger" %}
If you don't have any devices configured, this script will exit. See [#configuring-np.sh](quick-ssh-picker-script.md#configuring-np.sh "mention") below to set this script up for your use.
{% endhint %}

Here is the script template which we store in GitHub:

{% @github-files/github-code-block url="https://github.com/atsign-foundation/noports/blob/trunk/packages/dart/sshnoports/bundles/shell/magic/sshnp.sh" %}

### Variables in np.sh

The idea behind configuring np.sh is to give yourself a sane set of defaults for using sshnp. You can override any of these defaults in the script by passing the flag for sshnp to np.sh. For example:

`./np.sh -f @bob` - will replace the `client_atsign` default value with `@bob` at runtime.

#### Configuring np.sh

To configure np.sh, simply modify any of the variables surrounded by `SCRIPT METADATA` and `END METADATA`.

`client_atsign` is the default atSign for the `-f` or `--from` argument in sshnp.

`device_atsign` is the default atSign for the `-t` or `--to` argument in sshnp.

`host_atsign` is the default atSign for the `-r` or `--srvd` argument in sshnp.

`devices` is a bash array of all the device names you want quick access to, use a space to separate device names.

`additional_args` is all of the additional arguments you wish to have enabled for sshnp by default, this is a good place to enable things like `-s` or `-i` or `-v`

