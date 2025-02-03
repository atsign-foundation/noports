# MacOS Device Installation

{% include "../../.gitbook/includes/device-warning-setup-client-first.md" %}

## Step 1 : Activate the device atSign from your `client machine`

If you've already activated the device atSign skip to [step 2](device.md#step-2-installing-on-the-device).

{% include "../../.gitbook/includes/device-activate-preamble.md" %}

### (1.1) Download the activation software on the `client machine`

{% include "../../.gitbook/includes/universal.sh-preamble.md" %}

{% include "../../.gitbook/includes/universal.sh-download-command.md" %}

### (1.2) Run the installer

{% include "../../.gitbook/includes/universal.sh-execute.md" %}

{% include "../../.gitbook/includes/universal.sh-execute-activate-only.md" %}

### (1.3) Activate the device atSign from the `client machine`

{% include "../../.gitbook/includes/activate-cli-device-unix.md" %}

## Step 2 : Installing on the `device`

### (2.1) Download the installer

{% include "../../.gitbook/includes/universal.sh-download-command.md" %}

### (2.2) Run the installer

{% include "../../.gitbook/includes/universal.sh-execute.md" %}

{% include "../../.gitbook/includes/universal.sh-execute-device-detail.md" %}

***

## Step 3: Authorizing the device atSign

### (3.1) Generate a passcode from your `client machine`

{% include "../../.gitbook/includes/apkam-1-unix.md" %}

### (3.2) Make an authorization request from your `device machine`

{% include "../../.gitbook/includes/apkam-2-unix.md" %}

### (3.3) Approve the authorization request from your `client machine`

{% include "../../.gitbook/includes/apkam-3-unix.md" %}

{% include "../../.gitbook/includes/installation-complete-visit-usage.md" %}
