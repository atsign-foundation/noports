---
icon: server
description: Begin with the three steps below
---

# Device installation

## Overview

The NoPorts daemon (a.k.a. sshnpd) is installable as a background service in many ways. Choose the best option for your environment. The service may be installed as a `systemd unit`, `docker container`, `tmux session`, or as a background job using `cron` and `nohup`. The binaries can also be installed standalone so that you can install your own custom background service.

### :warning: This guide doesn't support Windows

On windows, we strongly recommend sticking to our automated installation process on Windows. This is because properly installing NoPorts as a Windows service requires making entries in the registry. If you want to create a custom installer for your organization, please speak to us directly at [info@noports.com](mailto:info@noports.com).

## 1. Download

### 1.a. Download from GitHub

You can [download a release from GitHub](https://github.com/atsign-foundation/noports/releases/), or see the table below to download the latest release for your platform.

{% include "../../../.gitbook/includes/linux-macos-release-table.md" %}

### 1.b. Download using curl

Alternatively, if you want to download from the command line, you can do so with curl.

{% tabs %}
{% tab title="Linux" %}
**x64:**

```sh
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-x64.tgz -o sshnp.tgz
```

**arm64:**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm64.tgz -o sshnp.tgz
```

**arm:**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm.tgz -o sshnp.tgz
```

**risc-v:**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-riscv.tgz -o sshnp.tgz
```
{% endtab %}

{% tab title="macOS" %}
**x64 (intel):**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-x64.zip -o sshnp.zip
```

**arm64 (apple):**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-arm64.zip -o sshnp.zip
```
{% endtab %}
{% endtabs %}

## 2. Unpack the Archive

If you downloaded from GitHub, the file name may be slightly different.

{% tabs %}
{% tab title="Linux" %}
```bash
tar -xf sshnp.tgz
```
{% endtab %}

{% tab title="macOS" %}
```bash
unzip sshnp.zip
```
{% endtab %}
{% endtabs %}

## 3. Install sshnpd

See the links in the table below to continue with the installation process.

<table><thead><tr><th width="196" data-type="content-ref">Installation method</th><th>When to use this method</th></tr></thead><tbody><tr><td><a href="systemd-unit.md">systemd-unit.md</a></td><td>You are on Linux and have root access. (Recommended)</td></tr><tr><td><a href="tmux-session.md">tmux-session.md</a></td><td>You have tmux installed, or can install it. (Deprecated)</td></tr><tr><td><a href="headless.md">headless.md</a></td><td>If you do not have root access and cannot install tmux (Deprecated)</td></tr><tr><td><a href="standalone-binaries.md">standalone-binaries.md</a></td><td>You want to manually setup the background service after downloading the binaries. (roll your own)</td></tr></tbody></table>
