# TP-002: Make policy_tests work — Status

**Current Step:** Not Started
**Status:** 🔵 Ready for Execution
**Last Updated:** 2026-04-30
**Review Level:** 1
**Review Counter:** 0
**Iteration:** 0
**Size:** M

> **Hydration:** Checkboxes represent meaningful outcomes, not individual code
> changes. Workers expand steps when runtime discoveries warrant it — aim for
> 2-5 outcome-level items per step, not exhaustive implementation scripts.

---

### Step 0: Preflight

**Status:** ⬜ Not Started

- [ ] Required files and paths exist
- [ ] Dependencies satisfied
- [ ] Existing uncommitted changes in the file scope are identified before editing and preserved unless they are part of this task
- [ ] Confirm Docker is available and no stale policy-test containers from previous runs are still active

---

### Step 1: Reproduce and characterize the current policy_tests failure

**Status:** ⬜ Not Started

- [ ] Run static checks for the e2e package to identify compile-time blockers before the full e2e run
- [ ] Run a default or minimal default-matrix `policy_tests` command from the repo root with explicit atSigns and a unique `--test-run-id`
- [ ] Capture the failing stage, command, expected result, actual result, relevant log paths, and whether stale Docker containers or stale policy state contributed
- [ ] Compare the observed failure with `PLAN-policy-tests-fix.md` and `tests/e2e_all_v2/lib/policy_tests/README.md` without assuming either document is current

---

### Step 2: Fix the policy flow at the narrowest layer

**Status:** ⬜ Not Started

> ⚠️ Hydrate: Expand checkboxes when entering this step based on the concrete failure found in Step 1.

- [ ] Implement the smallest source changes needed for `npp_test` and `npp_atserver_test` to produce the expected deny/deny/allow/deny policy stages
- [ ] Ensure policy rule mutation and inspection use the correct policy-manager atSign and correct policy-server flavor (`npp` vs `npp_atserver`)
- [ ] Ensure daemon/policy container names, policy directories, and log paths are unique per test permutation and do not reuse stale state unexpectedly
- [ ] Preserve concise success output while keeping failure-only client, daemon, and policy log fragments available
- [ ] Run targeted verification for the changed policy-test files

---

### Step 3: Update docs and CI-facing expectations if behavior changed

**Status:** ⬜ Not Started

- [ ] Update `tests/e2e_all_v2/lib/policy_tests/README.md` if commands, test stages, artifact locations, or supported assumptions changed
- [ ] Update `.github/workflows/e2e_all.yaml` only if the local fix requires CI command/argument changes
- [ ] Update the policy plan documents only if they would otherwise mislead future maintainers about the now-current behavior
- [ ] Do not add generated logs, `.atKeys`, Docker artifacts, or local run directories to tracked files

---

### Step 4: Testing & Verification

**Status:** ⬜ Not Started

- [ ] `cd tests/e2e_all_v2 && dart pub get` passes
- [ ] `cd tests/e2e_all_v2 && dart analyze` passes
- [ ] Default policy test matrix passes with both `npp_test` and `npp_atserver_test`
- [ ] No policy/daemon Docker container remains running after completion
- [ ] All failures introduced by this task are fixed

---

### Step 5: Documentation & Delivery

**Status:** ⬜ Not Started

- [ ] "Must Update" docs modified
- [ ] "Check If Affected" docs reviewed
- [ ] Discoveries logged
- [ ] Exact verification commands, pass/fail results, and environment assumptions recorded

---

## Reviews

| #   | Type | Step | Verdict | File |
| --- | ---- | ---- | ------- | ---- |

---

## Discoveries

| Discovery | Disposition | Location |
| --------- | ----------- | -------- |

---

## Execution Log

| Timestamp  | Action      | Outcome                         |
| ---------- | ----------- | ------------------------------- |
| 2026-04-30 | Task staged | PROMPT.md and STATUS.md created |

---

## Blockers

_None_

---

## Notes

_Reserved for execution notes_
