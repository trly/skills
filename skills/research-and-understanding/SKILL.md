---
name: research-and-understanding
description: "Researches and explains codebases inside agent workflows using Sourcegraph Deep Search for task scoping, implementation planning, and review. Use when an agent needs repository-wide or multi-repository understanding before coding, especially in agent-orchestrated or Minions-style delegated engineering tasks."
allowed-tools:
  - mcp__sourcegraph__deepsearch
  - mcp__sourcegraph__deepsearch_read
  - mcp__sourcegraph__keyword_search
  - mcp__sourcegraph__nls_search
  - mcp__sourcegraph__read_file
  - mcp__sourcegraph__compare_revisions
---

# Research and Understanding

Use Sourcegraph Deep Search as an agent-invoked research and planning skill inside delegated engineering workflows. The goal is not to make engineers manually operate Deep Search; the agent should decide when Deep Search will improve task success, invoke it with a precise objective, and translate the findings into concrete next actions.

This skill is designed for agents where engineers delegate work through Slack or another chat surface, and the agent orchestrates tools, repository context, and implementation steps end to end.

## Use this skill when

- A delegated task requires understanding behavior across many files, packages, services, or repositories.
- The agent needs to find the right implementation area before editing code.
- The user asks for impact analysis, architecture explanation, migration planning, or root-cause analysis.
- The task mentions broad concepts rather than exact file paths or symbols.
- The agent is about to make a non-trivial code change and needs a researched implementation plan.
- The agent needs a second pass review of an approach, diff, or rollout risk using repository evidence.
- Sourcegraph Code Search found clues, but the next step requires synthesis across those clues.

## Do not use this skill when

- The task is a small exact lookup answerable with a direct file read or keyword search.
- The user already supplied the exact file and change, and no broader context is needed.
- The only need is to find references to a known symbol; use symbol/reference tools first.
- The user explicitly asks to avoid external or long-running research.
- The agent would use Deep Search as a substitute for reading the files it is about to edit.

## Core principle

Deep Search is a research worker, not the final implementer. The orchestrating agent remains responsible for judgment: ask a focused Deep Search question, inspect the cited evidence, choose the smallest correct change, implement it, and verify it.

```diagram
╭──────────────╮      ╭──────────────────╮      ╭────────────────╮
│ Engineer     │─────▶│ Agent            │─────▶│ Deep Search     │
│ Slack task   │      │ Orchestrator     │      │ Research skill  │
╰──────────────╯      ╰────────┬─────────╯      ╰───────┬────────╯
                               │                        │
                               ▼                        ▼
                        ╭──────────────╮        ╭────────────────╮
                        │ Code Search  │◀──────▶│ Repo evidence   │
                        │ File reads   │        │ Findings + plan │
                        ╰──────┬───────╯        ╰────────────────╯
                               │
                               ▼
                        ╭──────────────╮
                        │ Implement +  │
                        │ verify       │
                        ╰──────────────╯
```

## Invocation workflow

### 1. Classify the delegated task

Before invoking Deep Search, identify what role it should play:

- **Locate**: Find where a behavior, subsystem, or integration is implemented.
- **Explain**: Explain architecture, data flow, control flow, or ownership boundaries.
- **Plan**: Produce an implementation or migration plan grounded in repository evidence.
- **Debug**: Investigate a failure, regression, incident, flaky test, or surprising behavior.
- **Review**: Assess a proposed change, diff, rollout, or risk area.
- **Compare**: Understand what changed between revisions, versions, branches, or services.

If the task is already localized, use normal code search and file reads instead.

### 2. Give Deep Search a precise research brief

Ask one focused question per Deep Search invocation. Include:

- The repository or repository family, if known.
- The user-visible goal or defect.
- Relevant files, symbols, services, errors, tests, logs, or APIs already known.
- The expected output shape: implementation locations, evidence, risks, plan, or review findings.
- Constraints such as avoiding changes, focusing on backend only, or checking compatibility.

Good brief:

```text
In github.com/acme/payments and related payment-service repositories, find how idempotency keys are validated for refund creation. Return the request flow, key files and functions, tests that define behavior, and the smallest safe implementation points for adding a new validation rule.
```

Weak brief:

```text
Look into payments.
```

### 3. Prefer Deep Search after initial scoping clues

When possible, seed Deep Search with context from quick local or Sourcegraph searches:

- Exact error messages.
- Candidate repository names.
- Service names from docs, manifests, or package metadata.
- Routes, RPC names, queue names, database table names, or config keys.
- Files already inspected and what they did or did not explain.

This keeps Deep Search focused and makes its answer more actionable.

### 4. Handle asynchronous results

If `mcp__sourcegraph__deepsearch` returns a polling link instead of a completed answer, call `mcp__sourcegraph__deepsearch_read` with that link or token until the result is available. Do not abandon the task solely because the research is asynchronous.

### 5. Validate and convert findings into action

After Deep Search returns:

1. Extract the files, symbols, tests, and constraints it cites.
2. Read the most relevant files directly before editing.
3. Check whether the recommended plan is the smallest correct change.
4. Implement through normal coding tools.
5. Run the narrowest meaningful validation.
6. Summarize both the code outcome and how Deep Search informed it.

Do not blindly follow Deep Search if local code evidence contradicts it.

## Agent decision policy

Use this decision policy inside agent-style orchestration:

| Task signal | Agent action |
| --- | --- |
| Exact file, exact requested edit | Read file and edit directly; skip Deep Search. |
| Exact symbol or error string, unknown implementation area | Use keyword/symbol search first; invoke Deep Search if the flow spans multiple files or services. |
| Broad feature request in unfamiliar code | Invoke Deep Search for implementation map and plan before coding. |
| Cross-service behavior or integration | Invoke Deep Search early with repository and service names. |
| Regression or production bug with unclear root cause | Invoke Deep Search for root-cause hypotheses and evidence, then verify locally. |
| Migration, deprecation, or API behavior change | Invoke Deep Search for impact analysis and rollout plan. |
| Code review or risk assessment | Invoke Deep Search with the diff, branch, or changed files and ask for evidence-backed risks. |

## Deep Search prompt templates

### Implementation scoping

```text
In <repo or repos>, determine where <feature or behavior> is implemented. Include the main entrypoints, internal flow, relevant tests, and the smallest safe files to change for <requested outcome>. Cite file paths and symbols.
```

### Debugging

```text
Investigate why <symptom/error/test failure> happens in <repo or service>. Use repository evidence to identify likely root cause, affected code paths, existing tests, and a minimal fix strategy. Distinguish confirmed evidence from hypotheses.
```

### Migration planning

```text
In <repo family>, assess the impact of migrating from <old behavior/API/dependency> to <new behavior/API/dependency>. Return affected files, call sites, tests, compatibility risks, and an ordered implementation plan.
```

### Architecture or flow explanation

```text
Explain how <system or workflow> works across <repo or repos>. Focus on request/data flow, ownership boundaries, persistence, external dependencies, and files that an implementation agent should inspect before changing behavior.
```

### Review

```text
Review the proposed change in <branch/commit/diff/files> for correctness, missing tests, security or data-handling risks, and compatibility with existing code patterns. Cite concrete evidence and prioritize actionable findings.
```

## Agent integration pattern

When positioning Deep Search as an agent skill, present it as an agent capability that improves task completion quality rather than a separate destination for engineers.

Recommended behavior:

1. Engineer delegates a task in Slack using normal engineering language.
2. Agent classifies whether repository-wide understanding is needed.
3. Agent invokes Deep Search with a structured research brief.
4. Deep Search returns an evidence-backed map, plan, or risk review.
5. Agent reads the cited source files, makes the change, and runs validation.
6. Agent replies in Slack with the outcome, changed files, tests run, and remaining risks.

Example Slack-facing summary:

```markdown
I used Deep Search to map the refund idempotency flow before changing code. It pointed to `api/refunds.ts`, `internal/idempotency/checker.go`, and the refund contract tests. I added validation in the shared checker and updated the public API tests. Validation: `go test ./internal/idempotency ./api/refunds` passed.
```

## Quality expectations

- Deep Search outputs must be evidence-backed with repository paths, symbols, tests, commits, or configuration names.
- The agent must read cited files directly before editing them.
- The agent must not use Deep Search findings as a replacement for verification.
- The agent should preserve a concise audit trail: question asked, key findings, code changed, validation run.
- The agent should avoid exposing internal chain-of-thought; summarize conclusions, evidence, and decisions.

## Common failure modes to avoid

- Asking Deep Search a vague question and receiving a vague plan.
- Invoking Deep Search for a one-line edit that code search can solve faster.
- Treating Deep Search as authoritative without inspecting source files.
- Running multiple broad Deep Searches instead of narrowing with exact search clues.
- Returning research to the engineer without completing the delegated implementation when implementation was requested.
- Overstating confidence when Deep Search found incomplete or ambiguous evidence.

## Reporting format

When Deep Search materially influenced the work, include a compact note in the agent's final response:

```markdown
## Outcome
- Implemented <change>.

## Deep Search findings used
- <finding with file/symbol evidence>
- <finding with test or risk evidence>

## Verification
- `<command>` passed.

## Remaining risk
- <only if something is unverified or ambiguous>
```

For read-only research tasks, report:

```markdown
## Answer
<concise conclusion>

## Evidence
- `<path>`: <what it shows>
- `<path>`: <what it shows>

## Recommended next step
<one or two concrete actions>
```

## Important constraints

- Do not create issues, pull requests, or tickets unless the user explicitly asks.
- Do not send proprietary code, secrets, customer data, or unnecessary private context in the Deep Search prompt.
- Do not broaden the delegated task beyond what the engineer asked for.
- Do not modify code during a research-only request.
- Prefer one targeted Deep Search invocation over multiple exploratory invocations.
