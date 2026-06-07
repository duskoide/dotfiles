---
description: "Fire-and-forget multi-agent workflow: plan, test, implement, PR"
agent: build
---

You are executing the autonomous multi-agent workflow. Run all phases without waiting for user input. The user has walked away.

**Task reference:** $ARGUMENTS

If `$ARGUMENTS` is empty, stop immediately: "Usage: `/workflow <LINEAR-ISSUE-ID>` (e.g. `/workflow SUN-123`)"

---

## Phase 1: Repo Setup

Verify you are at the bare repo root and the environment is ready.

1. Confirm `.bare/` directory exists in the current working directory. If not, stop: "Not at bare repo root. Run from `~/repos/veo/sunstone/`."
2. Run `gh auth status`. If auth is expired or missing, stop: "GitHub CLI auth expired. Run `gh auth login` before retrying."
3. Proceed to Phase 2 to get issue context before creating the worktree.

---

## Phase 2: Issue Context

Use `@pm` to fetch the Linear issue matching `$ARGUMENTS`:

- Issue title, description, acceptance criteria
- Labels and priority
- Any existing branch name

If the issue does not exist or `@pm` fails, stop with error.

Derive a branch name: `philip/<issue-id-lowercase>-<slugified-title>` (e.g. `philip/sun-123-add-retry-logic`). Validate: only `[A-Za-z0-9._/-]`, no leading `-`.

---

## Phase 3: Repo Setup (continued)

From the repo root (`~/repos/veo/sunstone/`):

1. `git fetch origin`
2. Compute worktree directory: replace all `/` with `-` in the branch name (e.g. `philip/sun-123-foo` becomes `philip-sun-123-foo`)
3. Check if worktree directory already exists. If yes, enter it and verify `git status --porcelain` is empty. If dirty, stop: "Worktree exists but has uncommitted changes. Clean it up first."
4. If worktree does not exist: `git worktree add <dir-name> -b <branch-name> master`
5. Change working directory to the new worktree.

---

## Phase 4: Plan

Analyze the codebase in the worktree context. Create a detailed implementation plan addressing the issue's requirements and acceptance criteria.

The plan should include:

- Problem summary (from issue context)
- Proposed approach with rationale
- Files to modify (with brief description of changes)
- New files to create
- Risks and open questions
- **Test Design (conditional — include for non-trivial tasks):**
  - Key behaviors to verify (what tests should assert)
  - Edge cases and error conditions worth testing
  - What explicitly should NOT be tested (prevents bloat)
  - Testability concerns (heavy external deps, GPU-only paths, etc.)

  **Include Test Design for:** Public API changes, bug fixes with behavioral impact, new features with business logic, multi-module changes.
  **Skip Test Design for:** Config-only changes, decorator swaps, import reorganization, documentation.
  When skipped, `@test` derives test cases directly from acceptance criteria.

---

## Phase 5: Review Plan

Dispatch `@check` and `@simplify` in parallel to review the plan.

Reviewers should evaluate testability:

- `@check`: Is the design testable? Are the right behaviors identified? (Review Framework §8)
- `@simplify`: Is the test scope appropriate? Over-testing proposed?

**Merge rules:**

- `@check` safety/correctness findings are hard constraints
- If `@simplify` recommends removing something `@check` flags as needed, `@check` wins
- Note conflicts explicitly

**Review loop (max 3 cycles):**

1. Send plan to both reviewers
2. Merge findings
3. If verdict is ACCEPTABLE from both (or JUSTIFIED COMPLEXITY from `@simplify`): proceed to Phase 6
4. If BLOCK or NEEDS WORK: revise the plan addressing findings, then re-review
5. **Convergence detection:** if reviewers return the same findings as the previous cycle, stop the loop early
6. If still unresolved after 3 cycles: note unresolved blockers and proceed anyway (they will be documented in the PR)

---

## Phase 6: Split into Tasks

Break the approved plan into discrete tasks for `@make`. Each task needs:

| Required                | Description                                                                                     |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| **Task**                | Clear description of what to implement                                                          |
| **Acceptance Criteria** | Specific, testable criteria (checkbox format)                                                   |
| **Code Context**        | Actual code snippets from the codebase, not just file paths                                     |
| **Files to Modify**     | Explicit list, mark new files with "(create)"                                                   |
| **Test File**           | Path for test file (colocated pattern), e.g., "sunstone/config/tests/test_validate.py (create)" |

Include **Integration Contracts** when a task adds/changes function signatures, APIs, config keys, or has dependencies on other tasks.

Include **Test Design** from Phase 4 when available, attached to the relevant task(s).

**Task size:** ~10-30 minutes each, single coherent change, clear boundaries.

---

## Phase 7: Write Tests

For each task from Phase 6, dispatch `@test` with:

- The task spec (acceptance criteria, code context, files to modify)
- The Test Design section from the plan (if provided)
- The test file path to create (following colocated pattern)

`@test` writes failing tests and verifies RED with structured failure codes.

**Post-step file gate (MANDATORY):**
Before dispatching `@test`, snapshot the current changed files:

```bash
git diff --name-only > /tmp/pre_test_baseline.txt
```

After `@test` completes, validate only NEW changes:

```bash
git diff --name-only | comm -23 - /tmp/pre_test_baseline.txt > /tmp/test_new_files.txt
```

All new files must match: `**/test_*.py`, `**/*_test.py`, `**/conftest.py` (new only), `**/test_data/**`, `**/test_fixtures/**`.
If any non-matching file appears: discard `@test` output, report violation.

**Decision table — handling `@test` results:**

| Condition                                  | Action                                                                                                      |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `TESTS_READY` + `escalate_to_check: false` | Proceed to Phase 8                                                                                          |
| `TESTS_READY` + `escalate_to_check: true`  | Route tests to `@check` for light review. `@check` diagnoses, caller routes fixes to `@test`. Then proceed. |
| `NOT_TESTABLE`                             | Route to `@check` for sign-off on justification. If approved, task goes to `@make` without tests.           |
| `BLOCKED`                                  | Investigate. May need to revise task spec or plan.                                                          |
| Test passes immediately                    | Investigate — behavior may already exist. Task spec may be wrong.                                           |

**Parallelism:** Independent tasks can have tests written in parallel.
**Constraint:** `@test` must not modify existing conftest.py files (prevents collision during parallel execution).

---

## Phase 8: Implement

Execute each task by dispatching `@make` with:

- The task spec (from Phase 6)
- Relevant code context (actual snippets)
- **Pre-written failing tests and handoff from `@test` (if TESTS_READY)**

`@make` runs in TDD mode when tests are provided:

1. Entry validation: run tests, verify RED, check failure codes match handoff
2. Implement minimal code to make tests pass (GREEN)
3. Regression check on broader area
4. Refactor while keeping green
5. Report RED→GREEN evidence

**Escalation:** If `@make` flags test quality concerns during entry validation:

1. `@make` reports the issue to caller
2. Caller routes to `@check` for diagnosis
3. `@check` reports findings
4. Caller routes to `@test` for fixes
5. Fixed tests return to `@make`

For NOT_TESTABLE tasks, `@make` runs in standard mode.

After all tasks complete, verify overall integration:

- Run the project's test suite if available
- Run linting/type checking if configured
- Fix any integration issues between tasks

---

## Phase 9: Final Review

Dispatch `@check` and `@simplify` in parallel to review the full implementation (all changes across all files).

Provide reviewers with:

- The original plan
- The full diff (`git diff master...HEAD`)
- Any decisions or deviations from the plan

**Review loop (max 3 cycles):**

1. Send implementation to both reviewers
2. Merge findings (same precedence rules as Phase 5)
3. If ACCEPTABLE: proceed to Phase 10
4. If issues found: fix them directly (no need to re-dispatch `@make` for small fixes), then re-review
5. **Convergence detection:** same findings twice = stop loop early
6. If unresolved after 3 cycles: document blockers, proceed to PR anyway

---

## Phase 10: Commit, PR, and Wrap Up

### Commit

- Stage all changes
- Write a conventional commit message summarizing the implementation
- If changes are large/varied, use multiple atomic commits (one per logical unit)

### Draft PR

- `gh pr create --draft --title "<conventional title>" --body "<execution report>"`
- PR body should include:
  - Summary of what was implemented
  - Link to Linear issue
  - Acceptance criteria checklist (from issue)
  - Files changed with brief descriptions
  - TDD summary: X tasks with tests (RED→GREEN), Y tasks NOT_TESTABLE with justifications
  - Any test quality escalations and their resolution
  - Unresolved blockers (if any from review loops)
  - Review cycle outcomes

### Linear Update

- Use `@pm` to post a comment on the Linear issue with a link to the draft PR
- If the issue description has checkboxes that were addressed, update them

### Local Summary

- Write `.opencode/workflow-summary.md` in the worktree with:
  - Run timestamp
  - Issue reference and title
  - Branch and PR link
  - Summary of implementation
  - TDD evidence (RED→GREEN per task, NOT_TESTABLE justifications)
  - Review outcomes (plan review + final review verdicts)
  - Unresolved items (if any)
  - Files changed

---

## Failure Handling

At any phase, if an unrecoverable error occurs:

1. Write `.opencode/workflow-summary.md` with what was completed and what failed
2. If any code was written, commit it with message `wip: incomplete workflow run for <issue-id>`
3. If a branch exists with commits, create the draft PR noting it is incomplete
4. Stop execution

**Never hang on interactive prompts.** If any command appears to require input, treat it as a failure and follow the above procedure.
