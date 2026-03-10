# e2e_all

## Usage

Run the full `e2e_all` test pack with:

```bash
tests/e2e_all/scripts/main.sh \
  @client_atsign \
  @daemon_atsign \
  @relay_atsign \
  @relay_latest_atsign \
  @policy_atsign \
  @policy_latest_atsign \
  @events_atsign
```

Optional flags:

```text
-r <root host>        Override the root domain. Default: root.atsign.org
-t <tests>            Space-separated test script names to run
-s <daemon versions>  Space-separated daemon versions
-c <client versions>  Space-separated client versions
-u <policy versions>  Space-separated policy versions
-w <seconds>          Daemon start wait time
-n                    Reuse existing local builds/images when available
-p                    Enable parallelized setup and test execution
```

## Example

Run a fast sanity check locally:

```bash
tests/e2e_all/scripts/main.sh \
  @npe2e_client \
  @npe2e_daemon \
  @rv_dev \
  @npe2e_relay_latest \
  @npe2e_policy \
  @npe2e_policy_latest \
  @npe2e_events \
  -t noop \
  -r root.atsign.wtf

## Developer

### Prerequisites

To run the `e2e_all` scripts locally, you need:

- Docker installed
- The Docker daemon running
- Docker registry access configured with `docker login`
- macOS or Linux

Notes:

- The shell scripts only handle macOS and Linux runtime setup.
- The Docker-based daemon and policy startup flow assumes local Docker access is available from the shell running the scripts.

### Docker Image Naming

The `e2e_all` harness uses separate Docker image namespaces for daemon containers and policy containers.

Daemon images use:

```text
atsigncompany/noports_e2e_all_<type>:current
atsigncompany/noports_e2e_all_<type>:v<version>
```

Examples:

```text
atsigncompany/noports_e2e_all_d:current
atsigncompany/noports_e2e_all_d:v5.13.0
atsigncompany/noports_e2e_all_c:current
```

Policy images use:

```text
atsigncompany/noports_e2e_all_policy_<type>:current
```

Examples:

```text
atsigncompany/noports_e2e_all_policy_d:current
```

Notes:

- Daemon image names come from `getDockerDaemonImageName`.
- Policy image names come from `getDockerPolicyImageName`.
- Policy services currently support only the current branch Dart policy image, so `e2e_all` only runs `d:current`.
- `@policyAtSign` is currently ignored by the harness because there is no release policy service to run yet.
- `@policyLatestAtSign` is the atSign used for the current branch policy service.
