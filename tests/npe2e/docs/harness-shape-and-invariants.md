# npe2e harness — shape and invariants

Status: four packs (`core_tests`, `relay_tests`, `policy_tests`,
`revocation_tests`) live in `tests/npe2e`, each a job of
`.github/workflows/e2e_all.yaml`. The older shell harness `tests/e2e_all/scripts/main.sh` still runs
as a separate job in the same workflow; npe2e does not replace it yet.

## Direction

npe2e is the Dart end-to-end harness: it fetches or compiles client binaries,
builds daemon/npp/relay Docker images, enrols APKAM keys per actor atSign,
starts each actor in its own container, then drives the real client binaries on
the host against them. Every pack is a version matrix — the point is catching
cross-version breakage between a client, a daemon, and (for policy and relay) a
third actor.

The npe2e harness is split into three packs rather than one runner because the
packs differ in every dimension that would otherwise become a union type: actor
sets (`policy_tests` adds npp and npp_atServer atSigns; `relay_tests` requires
`selfRelayVersions.length * 2` distinct self-relay atSigns, validated at
`lib/relay_tests/relay_tests.dart:52`), result shape (`PolicyTestResult` carries
a policy version, `RelayTestResult` carries relay kind and 443 flags), and CI
budget (`policy_tests` runs with `--test-timeout-seconds 480`, the others take
the 300s default). Each pack owns its `bin/` entrypoint, params, context,
logging, print utils and result type; mechanics shared by all packs — Docker
images and instances, APKAM enrolment, client-binary fetch, ssh keys, version
parsing — sit directly in `lib/`.

## Decisions

**`revocation_tests` runs on an ephemeral environment with atSigns made for
the run.** It revokes the enrollments it tests, so it never runs against
atSigns another job or person uses: CI starts an EE
(`tests/tools/ee/setup_ee.sh`) with its own atSigns, and a local run names its
own.

**Each npe2e pack runs on its own atSign set in CI.** `core_tests` takes
client01/daemon01, `policy_tests` takes client02/daemon02 plus policy01/policy02,
`relay_tests` takes client03/daemon03 plus relay01–06
(`.github/workflows/e2e_all.yaml:90-132`). The matrix runs `fail-fast: false`,
so the three legs are concurrent; sharing one atSign pair across packs would
double-book APKAM device enrolments and cross-deliver notifications. Rejected:
one pair plus a serialized matrix — that trades a correctness property for
3× wall-clock.

**`testRunId` is derived per run+attempt in CI, not from the git hash.** The
default is the short git hash (`lib/core_tests/core_tests.dart:67`,
`lib/policy_tests/policy_tests.dart:56`,
`lib/relay_tests/relay_tests.dart:74`); CI overrides it with
`md5(run_id-run_attempt)` truncated to 8 chars
(`.github/workflows/e2e_all.yaml:180-184`), because re-runs of the same commit
otherwise collide on the same APKAM device enrolment against the shared atSigns.
Local runs deliberately keep the git-hash default — re-running one commit reuses
the run directory and container names, which is what you want while iterating.
`tests/npe2e/README.md` documents the two bits of state to clear first.

**`needs: npe2e` on the `e2e_all` job is a lock, not a build dependency.** Both
jobs authenticate as `@npe2e_org_*` atSigns, so the `needs:` serializes them to
avoid double-booking within a run; `if: !cancelled()`
(`.github/workflows/e2e_all.yaml:27-33`) keeps `e2e_all` running when an npe2e
leg fails, so flaky shared infra cannot silently skip it.

**The npp and npp_atServer policy flows run sequentially.**
`lib/policy_tests/policy_tests.dart:251-272`. Both flows build their admin
AtClient through the per-isolate `AtClientManager` singleton and share the
client/daemon atSigns, and the npp flow's admin RPCs ride notifications on a
single atSign — under that contention response notifications go missing and the
RPC await never returns, producing 30+ minute hangs. Rejected: the previous
`Future.wait` shape, which was faster and was the standing trigger. Tripwire: do
not re-parallelise these two flows without first giving each its own atSigns.

**Bootstrap failures are hard stops, not just failures.** `core_tests` abandons
the run when any `001_minus_s_flag` test fails
(`lib/core_tests/core_tests.dart:269-288`), and `relay_tests` skips its npt tests
when SSH-key setup fails (`lib/relay_tests/relay_tests.dart:240,275-279`).
Downstream tests cannot distinguish "the daemon never came up" from a real
regression, so letting them run buries the one useful failure under dozens of
derived ones.

**Each pack revokes the APKAM enrolments it made, however the run ends.**
They carry sshnp and sshrvd access on shared atSigns, so none outlives its run.
The pack registers them with `ApkamRevocations` before enrolling, so a setup
that fails part way is covered, and revokes them in the `finally` of its entry
point (`coreTests`, `policyTests`, `relayTests`). A failed revoke is printed,
not thrown, so it cannot mask the run's own result.

**Tests are `Future<T> Function()` factories, not futures.** Each pack's runner
(`lib/core_tests/core_tests.dart:445`, `lib/policy_tests/policy_tests.dart:354`,
`lib/relay_tests/relay_tests.dart:364`) takes factories so a retry re-invokes
the test rather than re-awaiting a settled future, and so nothing starts before
its concurrency slot opens. Runners keep `batchSize` tests in flight, stagger
starts by 1s, and retry on either a timeout or a failed status.

## Not done yet

- **Retry exhaustion on timeout aborts the whole pack.** All three runners
  `rethrow` the `TimeoutException` instead of recording one failed test; the
  comment at `lib/core_tests/core_tests.dart:474-477` says why (no version info
  in scope at that point).
- **The three runners are near-identical copies.** All three result types extend
  `TestResult` (`lib/test_result.dart:3`), so one generic runner is possible;
  each copy exists only because it is typed on the pack's result class.
- **`--batch-size` > 1 in `policy_tests` puts concurrent tests on one npp
  atSign.** npp tests batch by npp version
  (`lib/policy_tests/tests/npp_test.dart:36-56`) and batches run in sequence,
  but within a batch every client×daemon permutation shares `context.nppAtsign`
  and its notification-based admin RPC channel — the same contention class the
  sequential-flow decision above removes. CI runs `--batch-size 2`.
- **No `concurrency:` group in `.github/workflows/e2e_all.yaml`.** Overlapping
  workflow runs
  double-book the fixed `@npe2e_org_*` atSigns. CI run-history analysis put the
  effect at the edge of noise (most policy failures occurred with no other
  policy job active), so this is knowingly unfixed.
- **`core_tests` and `policy_tests` leave their containers running on exit.**
  Containers start with `--rm` (`lib/docker_instance.dart:78-91`) so they vanish
  once stopped, but only `relay_tests` stops them, via
  `stopNptRelayEnvironment` in a `finally`
  (`lib/relay_tests/relay_tests.dart:280-282`).

## Reference

- `tests/npe2e/README.md` — running a pack, including against a local atStack
- `lib/core_tests/`, `lib/relay_tests/`, `lib/policy_tests/` — one directory per
  pack: entrypoint logic, params, context, logging, result type, and `tests/`
- `lib/apkam_setup.dart`, `lib/client_binary_utils.dart`,
  `lib/docker_utils.dart`, `lib/docker_instance.dart` — cross-pack mechanics
- `.github/workflows/e2e_all.yaml` — atSign allocation, per-pack flags,
  `testRunId` derivation
