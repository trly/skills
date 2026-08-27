---
name: find-enabled-h2-consoles
description: "Finds repositories with Maven or Gradle build files whose Spring Boot application configuration explicitly enables the H2 console. Use for Sourcegraph-based H2 console exposure audits across many repositories."
allowed-tools:
  - mcp__sourcegraph__keyword_search
  - mcp__sourcegraph__code_finder
  - mcp__sourcegraph__evaluator
  - mcp__sourcegraph__read_file
  - mcp__sourcegraph__list_repos
---

# Find Enabled H2 Consoles

Use Sourcegraph MCP tools to find repositories with Maven or Gradle build files, enumerate every standard Spring Boot application configuration file, and report files that explicitly set `spring.h2.console.enabled` to `true`.

## Use this skill when

- Auditing many repositories for possible H2 web console exposure.
- Looking for `spring.h2.console.enabled=true` in Spring Boot configuration.
- Finding explicit H2 console enablement for remediation.
- Producing an evidence-backed list of repositories and configuration files for remediation.

## Audit policy

Treat a repository as an audit candidate when it contains at least one file whose basename is:

- `pom.xml`
- `build.gradle`
- `build.gradle.kts`

Within candidate repositories, inspect every file whose basename matches:

```text
application.properties
application.yml
application.yaml
application-<profile>.properties
application-<profile>.yml
application-<profile>.yaml
```

Report a file only when `spring.h2.console.enabled` statically resolves to literal `true`. Do not report files with no active assignment, literal `false`, placeholders, expressions, aliases, templates, or values that cannot be resolved statically.

Spring Boot defaults `spring.h2.console.enabled` to `false`. Missing assignments are not findings in this audit. Do not claim that an explicitly enabled property alone makes the console reachable: classpath, web application type, security, network exposure, profiles, and runtime overrides also affect reachability.

## Workflow

### 1. Establish Sourcegraph scope

Use the repository or organization scope supplied by the user. If no scope is supplied, use the active Sourcegraph search context. Do not silently broaden a named organization or repository family.

Preserve any required filters throughout the scan, such as:

- `repo:^github\.com/acme/`
- `-repo:archived-project`
- `archived:no`
- `fork:no`
- `rev:<branch-or-commit>` when the user explicitly requests a revision

Use `mcp__sourcegraph__list_repos` only when the repository scope is ambiguous and repository-name discovery is necessary.

### 2. Find candidate repositories by build-file presence

Use a path query, not a content query. The build marker path expression is:

```text
(^|/)(pom\.xml|build\.gradle|build\.gradle\.kts)$
```

Validate the scoped query with `mcp__sourcegraph__keyword_search` before running an aggregate scan:

```text
<scope> type:path file:(^|/)(pom\.xml|build\.gradle|build\.gradle\.kts)$
```

Deduplicate results by repository. A monorepo with several build files is one candidate repository, but retain all build-file paths as evidence.

The build-file rule is intentionally broad and may include Java projects that are not Spring Boot applications. Label them **build-file candidates** until a matching Spring application configuration file is found. Do not infer Spring Boot solely from a Maven or Gradle filename.

### 3. Enumerate all matching application configuration files

Within candidate repositories, find paths matching:

```text
(^|/)application(-[^/]+)?\.(properties|ya?ml)$
```

Use exact path matching so files such as `application.properties.example`, `bootstrap.yml`, generated build output, and editor backups are not included.

Unless the user requests otherwise, exclude obvious generated or dependency directories when they appear in results, including:

```text
target/
build/
.gradle/
node_modules/
vendor/
```

Do not exclude `src/test/resources` or profile-specific files by default. Report their source set or path so the user can distinguish test-only findings from deployable configuration.

For a named repository whose layout is unclear — a monorepo, a non-standard module layout, or many profile files — use `mcp__sourcegraph__code_finder` to locate the configuration files instead of guessing at path patterns. See step 4.

### 4. Choose the correlation tool for the scope

Match the tool to the size of the scan. Do not reach for the evaluator by default; it is the heaviest option and is meant for exhaustive aggregation that the other tools cannot reach within their result caps.

| Situation | Tool |
| --- | --- |
| Confirming which paths exist for one scoped query | `mcp__sourcegraph__keyword_search` |
| One repository, or a handful of named repositories | `mcp__sourcegraph__code_finder` |
| A known repository with an unclear layout: monorepo, non-standard modules, many profiles | `mcp__sourcegraph__code_finder` |
| Dozens or more repositories needing exhaustive correlation and aggregate counts | `mcp__sourcegraph__evaluator` |

#### Using `code_finder`

`code_finder` is a per-repository file-finding agent. Identify repositories with step 2 first, then call it once per repository — do not hand it cross-repository discovery.

Name the repository first, state what you already know so it does not re-search it, and state explicit success criteria:

```text
In github.com/acme/orders, find every Spring Boot application configuration file
(application.properties, application.yml, application.yaml, and profile variants
application-<profile>.*) and report which ones assign spring.h2.console.enabled.
I already know the repo has pom.xml at the root and a services/ module directory.
Skip target/ and build/ output. Return file paths with line numbers for each
spring.h2.console.enabled assignment.
```

`code_finder` returns relevant paths and line ranges with context. It does not perform the literal-`true` classification, and its output is not evidence of exhaustive coverage. Read the returned paths with `mcp__sourcegraph__read_file` and classify them with steps 5 and 6. When completeness matters, confirm the file list with a scoped `type:path` query from step 3.

#### Using the evaluator

Use `mcp__sourcegraph__evaluator` when the repository count makes per-repository calls impractical, or when the report needs exhaustive counts across the whole scope. One evaluator script should:

1. Search for build-marker paths and collect candidate repositories.
2. Search for matching application configuration paths.
3. Keep only configuration files from candidate repositories.
4. Read each candidate configuration with `source.read_file`.
5. Identify files whose property resolves to literal `true`.
6. Return compact TSV rows for enabled files plus aggregate counts.

Use `search.keyword` for path queries and `source.read_file` for configuration content. Preserve `match.rev` when reading a revision-pinned result. Deduplicate by `repo + revision + path`.

Check every search's `stats.limitHit`. If a result cap or the evaluator's 1,000-file read limit prevents a complete scan, split the work into narrower repository scopes and combine the rows. Never describe a capped result as exhaustive.

### 5. Parse properties files

For `.properties` files:

- Ignore blank lines and lines whose first non-whitespace character is `#` or `!`.
- Support `=`, `:`, or whitespace as the key/value separator.
- Trim surrounding whitespace from the value.
- Match the exact key `spring.h2.console.enabled`.
- Treat an active literal `true`, case-insensitively, as **Enabled**.
- Do not report literal `false`, placeholders such as `${H2_CONSOLE_ENABLED}`, `${H2_CONSOLE_ENABLED:false}`, or other non-literal values.
- If the property is assigned more than once and every assignment is an unambiguous literal, apply file order; report only when the last active assignment is `true`. Do not report assignments whose ordering or structure cannot be resolved.

Account for Java properties continuation lines before classification. Do not match commented-out assignments.

### 6. Parse YAML files

Recognize both supported YAML forms:

```yaml
spring.h2.console.enabled: false
```

```yaml
spring:
  h2:
    console:
      enabled: false
```

For `.yml` and `.yaml` files:

- Ignore comments and quoted text that merely mentions the property.
- Respect indentation and YAML document separators (`---`).
- Match the exact flattened path `spring.h2.console.enabled`.
- Treat literal boolean `true` as **Enabled**. Do not report literal `false`.
- Do not report aliases, anchors, merge keys, placeholders, templating, duplicate keys, or non-literal values unless they can be resolved unambiguously to literal `true` from the file.
- Inspect every YAML document in the file. Report documents that explicitly resolve the property to `true`, including the document and line evidence. Do not report documents whose state is absent or cannot be resolved.

Do not use a regex match for `enabled:` without proving that it is nested under `spring.h2.console`.

### 7. Verify findings with direct reads

Use `mcp__sourcegraph__read_file` to inspect at least one explicit **Enabled** result and every parser edge case before reporting.

If direct inspection contradicts the aggregate parser, correct the classification and adjust the parsing approach before completing the scan. Verify with `read_file`, not with a second evaluator run.

When a repository's coverage is in doubt — an evaluator search hit a cap, or a path pattern may have missed a module — re-check that single repository with `mcp__sourcegraph__code_finder` and reconcile the file lists.

### 8. Report with traceability

Use this format:

```markdown
## H2 console audit

Scope: `<Sourcegraph scope>`

| Repository | Configuration | Source set/profile | Classification | Evidence |
| --- | --- | --- | --- | --- |
| github.com/acme/orders | src/main/resources/application-prod.yml | main / prod | Enabled | `spring.h2.console.enabled: true` at line 18 |

## Summary
- Build-file candidate repositories: <count>
- Candidates with matching Spring configuration: <count>
- Configuration files inspected: <count>
- Enabled: <count>
- Scan completeness: complete / incomplete (<reason>)
```

For every finding include the repository, exact path, classification, line number when available, and concise evidence. Keep test-only findings visible but clearly labeled.

## Important constraints

- This skill is read-only. Do not modify repositories, create batch changes, issues, or pull requests unless the user separately asks.
- Do not claim a repository is definitely a Spring Boot application solely because it has a Maven or Gradle build file.
- Do not claim the H2 console is reachable solely from this property; classpath, web application type, security, network exposure, profiles, and runtime overrides also affect reachability.
- Do not treat commented assignments, missing assignments, or non-literal assignments as enabled configuration.
- Do not treat a missing application configuration file as a finding. Report the repository only in candidate counts.
- Do not hide incomplete coverage caused by search limits, read limits, inaccessible repositories, or parser ambiguity.
