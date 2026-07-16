# Agent Workflow Harness

This repository is test-case oriented. Any AI agent or LLM working here must treat this file as a mandatory gate, not as optional advice.

If a request cannot be expressed as verifiable behavior and checked by tests, scripts, reviewable evidence, or an explicit human-approved exception, the agent must stop and ask for clarification instead of implementing it.

## Non-Negotiable Rule

Do not make implementation changes until the work has a validation target.

Every task must pass this sequence:

1. Define the behavior being changed.
2. Define concrete acceptance criteria.
3. Add or update tests, scripts, fixtures, or an equivalent validation checklist before implementation.
4. Run the new or changed validation and confirm it fails for the expected reason when possible.
5. Implement the smallest change that satisfies the validation.
6. Run targeted validation.
7. Run the broadest practical regression check.
8. Report the exact commands and results.

If any required validation cannot be run, the agent must say why, describe the residual risk, and avoid claiming the task is complete.

## Required Workflow

### 1. Specification

Before editing code, write down the effective spec in the working notes or final response:

- user-visible behavior
- inputs and outputs
- edge cases
- non-goals
- affected files or modules
- expected failure modes

For bugs, include the observed wrong behavior and the expected corrected behavior.

For features, include at least one normal case, one boundary case, and one error or awkward-input case when applicable.

### 2. Test Plan

Create or update a concrete test plan before implementation.

Prefer automated checks in this order:

1. Unit tests for pure behavior.
2. Integration tests for module boundaries.
3. Contract or CLI tests for public interfaces.
4. Smoke tests for full workflows.
5. Repro scripts, generated artifacts, screenshots, or manual checklists only when automation is not practical.

Tests must verify behavior, not merely implementation details. Do not write tests that only prove mocks were called unless that is the public contract.

### 3. Red Gate

When adding a test for new behavior or a bug fix, run the test before implementation and confirm it fails for the expected reason.

If the existing code already passes the new test, pause and explain what that means. The task may be a documentation issue, an already-fixed bug, or a bad test.

### 4. Green Gate

Implement the smallest coherent change that passes the test plan.

Follow existing repository style and APIs. Do not introduce new dependencies, broad rewrites, or architectural changes unless the spec requires them.

### 5. Refactor Gate

Refactor only after tests pass. Keep all tests green while improving names, structure, duplication, or local clarity.

Do not mix unrelated cleanup into the task.

### 6. Verification Gate

Run targeted checks first, then the broadest practical regression checks.

For this Julia bundle, the default checks are:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. test/interface_contract.jl
```

For changes touching encode/decode behavior, LDPC integration, synchronization, receiver logic, or the modulation interface, also run:

```bash
JUNA_INTERFACE_ROUNDTRIP=1 julia --project=. test/interface_contract.jl
```

If a command is too slow, unavailable, or blocked by missing local tools, report that explicitly and provide the strongest validation that was actually run.

### 7. Review Gate

Before finishing, inspect the diff and check:

- tests cover the requested behavior and important edge cases
- no tests were weakened, deleted, skipped, or snapshot-blessed to hide failures
- no unrelated files changed
- no generated caches, logs, or local artifacts were added
- public behavior, docs, and examples agree with the code
- failures and limitations are disclosed

## Done Means

A task is done only when:

- the spec is clear
- the validation target exists
- required checks pass
- the diff is scoped to the request
- the final report lists what changed and what was run

If these are not true, the agent must not present the task as complete.

## Prompt Contract For Agents

When an agent receives a task in this repository, it should internally translate it to:

```text
Implement this request using the Agent Workflow Harness:
1. Restate the behavior and acceptance criteria.
2. Add or update failing tests or equivalent validation first.
3. Implement the minimal fix.
4. Run targeted and practical regression checks.
5. Report files changed, commands run, and remaining risk.
Do not proceed if the request cannot be validated.
```
