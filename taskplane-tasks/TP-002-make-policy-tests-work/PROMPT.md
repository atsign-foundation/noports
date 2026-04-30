# Task: TP-002 - Make policy_tests work

**Created:** 2026-04-30
**Size:** M

## Review Level: 1 (Plan Only)

**Assessment:** This task is focused on the Dart e2e policy test harness, but it may touch policy-manager orchestration, Docker lifecycle, and CI expectations. It should receive plan review before implementation to avoid masking real policy failures or broadening scope.
**Score:** 3/8 — Blast radius: 1, Pattern novelty: 1, Security: 1, Reversibility: 0

## Canonical Task Folder

```
taskplane-tasks/TP-002-make-policy-tests-work/
├── PROMPT.md   ← This file (immutable above --- divider)
├── STATUS.md   ← Execution state (worker updates this)
├── .reviews/   ← Reviewer output (created by the orchestrator runtime)
└── .DONE       ← Created when complete
```

## Mission

Make the `policy_tests` runner in `tests/e2e_all_v2` pass reliably using the default policy matrix. The worker should identify the current failure mode, fix the policy-test harness at the narrowest appropriate layer, keep successful-run output concise, and preserve useful failure diagnostics for client, daemon, and policy-server stages.

## Dependencies

- **None**

## Context to Read First

> Only list docs the worker actually needs. Less is better.

**Tier 2 (area context):**

- `taskplane-tasks/CONTEXT.md`

**Tier 3 (load only if needed):**

- `tests/e2e_all_v2/AGENTS.md` — package-specific structure, commands, and test-harness conventions
- `tests/e2e_all_v2/lib/policy_tests/README.md` — intended policy flow and expected NPP/NPP-atServer behavior
- `PLAN-policy-tests-fix.md` — prior investigation and acceptance notes for this exact suite; treat as background, not proof that current code works
- `PLAN-policy-tests-documentation.md` — detailed policy runner matrix and log-layout notes, if the failure relates to runner arguments or artifacts

## Environment

- **Workspace:** repository root, with primary work under `tests/e2e_all_v2`
- **Services required:** Docker; Dart SDK; NoPorts e2e atSign keys available in `~/.atsign/keys` for the selected local or CI-style atSigns; root domain access to the configured atDirectory

## File Scope

> The orchestrator uses this to avoid merge conflicts: tasks with overlapping
> file scope run on the same lane (serial), not in parallel. List the files and
> directories this task will create or modify. Use wildcards for directories.

- `tests/e2e_all_v2/bin/policy_tests.dart`
- `tests/e2e_all_v2/lib/policy_tests/*`
- `tests/e2e_all_v2/lib/policy_tests/tests/*`
- `tests/e2e_all_v2/lib/docker_instance.dart`
- `tests/e2e_all_v2/lib/docker_utils.dart`
- `tests/e2e_all_v2/lib/process_utils.dart`
- `tests/e2e_all_v2/lib/print_test_utils.dart`
- `tests/e2e_all_v2/lib/policy_tests/README.md`
- `.github/workflows/e2e_all.yaml`
- `PLAN-policy-tests-fix.md`
- `PLAN-policy-tests-documentation.md`

## Steps

> **Hydration:** STATUS.md tracks outcomes, not individual code changes. Workers
> expand steps when runtime discoveries warrant it. See task-worker agent for rules.

### Step 0: Preflight

- [ ] Required files and paths exist
- [ ] Dependencies satisfied
- [ ] Existing uncommitted changes in the file scope are identified before editing and preserved unless they are part of this task
- [ ] Confirm Docker is available and no stale policy-test containers from previous runs are still active

### Step 1: Reproduce and characterize the current policy_tests failure

- [ ] Run static checks for the e2e package to identify compile-time blockers before the full e2e run
- [ ] Run a default or minimal default-matrix `policy_tests` command from the repo root with explicit atSigns and a unique `--test-run-id`
- [ ] Capture the failing stage, command, expected result, actual result, relevant log paths, and whether stale Docker containers or stale policy state contributed
- [ ] Compare the observed failure with `PLAN-policy-tests-fix.md` and `tests/e2e_all_v2/lib/policy_tests/README.md` without assuming either document is current

**Artifacts:**

- `taskplane-tasks/TP-002-make-policy-tests-work/STATUS.md` (modified)
- Relevant log/artifact paths recorded in STATUS.md discoveries, not copied into tracked source unless intentionally documenting behavior

### Step 2: Fix the policy flow at the narrowest layer

> ⚠️ Hydrate: Expand checkboxes when entering this step based on the concrete failure found in Step 1.

- [ ] Implement the smallest source changes needed for `npp_test` and `npp_atserver_test` to produce the expected deny/deny/allow/deny policy stages
- [ ] Ensure policy rule mutation and inspection use the correct policy-manager atSign and correct policy-server flavor (`npp` vs `npp_atserver`)
- [ ] Ensure daemon/policy container names, policy directories, and log paths are unique per test permutation and do not reuse stale state unexpectedly
- [ ] Preserve concise success output while keeping failure-only client, daemon, and policy log fragments available
- [ ] Run targeted verification for the changed policy-test files

**Artifacts:**

- `tests/e2e_all_v2/lib/policy_tests/*` (modified as needed)
- `tests/e2e_all_v2/lib/policy_tests/tests/*` (modified as needed)
- Shared e2e helpers under `tests/e2e_all_v2/lib/` only if the failure clearly belongs there

### Step 3: Update docs and CI-facing expectations if behavior changed

- [ ] Update `tests/e2e_all_v2/lib/policy_tests/README.md` if commands, test stages, artifact locations, or supported assumptions changed
- [ ] Update `.github/workflows/e2e_all.yaml` only if the local fix requires CI command/argument changes
- [ ] Update the policy plan documents only if they would otherwise mislead future maintainers about the now-current behavior
- [ ] Do not add generated logs, `.atKeys`, Docker artifacts, or local run directories to tracked files

**Artifacts:**

- `tests/e2e_all_v2/lib/policy_tests/README.md` (modified if needed)
- `.github/workflows/e2e_all.yaml` (modified if needed)
- `PLAN-policy-tests-fix.md` / `PLAN-policy-tests-documentation.md` (modified if needed)

### Step 4: Testing & Verification

> ZERO test failures allowed. This step runs the FULL relevant test suite as a quality gate.
> (Earlier steps should use targeted tests for fast feedback — see worker prompt.)

- [ ] Run `cd tests/e2e_all_v2 && dart pub get`
- [ ] Run `cd tests/e2e_all_v2 && dart analyze`
- [ ] Run the policy suite from repo root, for example:

```sh
dart run tests/e2e_all_v2/bin/policy_tests.dart \
  --client-atsign "@npe2e_client" \
  --daemon-atsign "@npe2e_device" \
  --relay-atsign "@rv_am" \
  --npp-atsign "@npe2e_policy" \
  --npp-atserver-atsign "@npe2e_policy_latest" \
  --base-directory "npe2e_policy" \
  --root-domain "root.atsign.org:64" \
  --test-run-id "tp002_<short_unique_id>"
```

- [ ] If local atSign names differ, run the same default policy matrix with the available local policy-test atSigns and record the exact command used
- [ ] Confirm no policy/daemon Docker container remains running after completion
- [ ] Fix all failures introduced by this task

### Step 5: Documentation & Delivery

- [ ] "Must Update" docs modified
- [ ] "Check If Affected" docs reviewed
- [ ] Discoveries logged in STATUS.md
- [ ] Final STATUS.md includes exact verification commands, pass/fail results, and any environment assumptions that prevented full local verification

## Documentation Requirements

**Must Update:**

- `taskplane-tasks/TP-002-make-policy-tests-work/STATUS.md` — log discoveries, verification commands, and final state

**Check If Affected:**

- `tests/e2e_all_v2/lib/policy_tests/README.md` — update if behavior, commands, stages, or artifact layout changed
- `PLAN-policy-tests-fix.md` — update if prior plan claims are now wrong or incomplete
- `PLAN-policy-tests-documentation.md` — update if policy runner matrix or artifact expectations changed
- `.github/workflows/e2e_all.yaml` — update only if CI invocation must change

## Completion Criteria

- [ ] All steps complete
- [ ] `cd tests/e2e_all_v2 && dart analyze` passes
- [ ] The default policy test matrix passes with both `npp_test` and `npp_atserver_test`
- [ ] Policy stages behave as intended: no rules denied, wrong policy port denied, allowed port succeeds, daemon permit-open mismatch denied
- [ ] Successful runs do not dump large Docker/client/policy logs; failures include enough targeted diagnostics
- [ ] No generated logs, keys, Docker artifacts, or local run directories are added to tracked files
- [ ] Documentation updated where behavior or commands changed

## Git Commit Convention

Commits happen at **step boundaries** (not after every checkbox). All commits
for this task MUST include the task ID for traceability:

- **Step completion:** `feat(TP-002): complete Step N — description`
- **Bug fixes:** `fix(TP-002): description`
- **Tests:** `test(TP-002): description`
- **Hydration:** `hydrate: TP-002 expand Step N checkboxes`

## Do NOT

- Expand task scope beyond making `policy_tests` work reliably
- Skip tests or mark the task complete without a policy-suite verification attempt
- Commit, copy, print, or add `.atKeys`, secrets, local credentials, or generated policy logs to tracked files
- Blanket-clean Docker containers unrelated to this test run without explicit evidence they are stale test artifacts
- Modify product policy semantics to make the test pass unless the test reveals a real product bug and the fix is reviewed
- Load docs not listed in "Context to Read First"
- Commit without the task ID prefix in the commit message

---

## Amendments (Added During Execution)

<!-- Workers add amendments here if issues discovered during execution.
     Format:
     ### Amendment N — YYYY-MM-DD HH:MM
     **Issue:** [what was wrong]
     **Resolution:** [what was changed] -->
