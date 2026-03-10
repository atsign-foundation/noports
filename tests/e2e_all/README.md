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
```
