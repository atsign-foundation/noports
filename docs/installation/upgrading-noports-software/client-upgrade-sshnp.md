---
icon: arrow-up-from-square
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

# NoPorts Client Upgrade

### Upgrade sshnp

Upgrading to the latest version of sshnp follows the same process as installation, as the installer automatically replaces existing binaries with the new ones.

To upgrade, follow the [installation guide](../advanced-installation-guides/client-installation-sshnp.md) up to **Step 3**, then return to this page to verify the upgrade.

### Verify the Upgrade

To check the current version of sshnp installed on your machine simply execute the binary:

{% tabs %}
{% tab title="Linux" %}
<pre class="language-sh"><code class="lang-sh"><strong>sshnp --version
</strong></code></pre>

The first line of output should contain the version information:

```sh
Version : x.x.x
```
{% endtab %}

{% tab title="macOS" %}
```bash
sshnp --version
```

The first line of output should contain the version information:

```tex
Version : x.x.x
```
{% endtab %}

{% tab title="Windows" %}
```powershell
sshnp.exe
```

The first line of output should contain the version information:

```tex
Version : x.x.x
```
{% endtab %}
{% endtabs %}

### Troubleshooting the Upgrade

If you continue to get an old version number, it's likely that there's an old binary which wasn't replaced on the machine. Try the following to debug your binary location:

{% tabs %}
{% tab title="Linux" %}
First, use this command to locate the sshnp binary:

```bash
command -v sshnp
```

The command should output the location of the binary which is on the `PATH`. Try deleting this binary then rerunning the installer.

```sh
rm "$(command -v sshnp)"
```
{% endtab %}

{% tab title="macOS" %}
First, use this command to locate the sshnp binary:

```bash
command -v sshnp
```

The command should output the location of the binary which is on the `PATH`. Try deleting this binary then rerunning the installer.

```sh
rm "$(command -v sshnp)"
```
{% endtab %}

{% tab title="Windows" %}
Since Windows doesn't include a dedicated installer, upgrading should be as simple as moving the new binary to wherever you installed the previous one.
{% endtab %}
{% endtabs %}
