---
name: create-batch-change
description: "Creates Sourcegraph Batch Changes batch spec YAML. Use when an agent needs to draft, scope, or validate a Sourcegraph batch change using Code Search queries and Sourcegraph MCP tools."
allowed-tools:
  - mcp__sourcegraph__keyword_search
  - mcp__sourcegraph__nls_search
  - mcp__sourcegraph__list_repos
  - mcp__sourcegraph__read_file
  - mcp__sourcegraph__finder
  - mcp__sourcegraph__evaluator
  - mcp__sourcegraph__deepsearch
  - mcp__sourcegraph__deepsearch_read
---

# Create Sourcegraph Batch Change Specs

Create Sourcegraph Batch Changes batch spec YAML that is narrowly scoped, query-backed, and ready for the user to preview with Sourcegraph Batch Changes tooling.

## Use this skill when

- The user asks to create, draft, review, or scope a Sourcegraph Batch Changes batch spec.
- The user needs a batch spec for a multi-repository code modification.
- The user wants help writing `on.repositoriesMatchingQuery`, `workspaces`, `steps`, or `changesetTemplate` sections.
- The user asks to validate which repositories or files a batch change would affect.
- The task involves Sourcegraph Code Search query syntax for batch change targeting.

## Core principle

A batch spec is only as safe as its repository query. Use Sourcegraph MCP tools to prove the target set before writing the final YAML. Prefer the narrowest query that finds the intended repositories and files, and default generated changesets to unpublished unless the user explicitly requests publishing.

```diagram
╭──────────────╮     ╭──────────────────╮     ╭────────────────────╮
│ User intent  │────▶│ Search query      │────▶│ Sourcegraph MCP     │
│ and change   │     │ candidates       │     │ validation          │
╰──────────────╯     ╰────────┬─────────╯     ╰─────────┬──────────╯
                              │                         │
                              ▼                         ▼
                       ╭──────────────╮          ╭──────────────╮
                       │ Batch spec   │◀─────────│ Evidence:    │
                       │ YAML         │          │ repos/files   │
                       ╰──────────────╯          ╰──────────────╯
```

## Workflow

### 1. Clarify the batch change objective

Identify these inputs before drafting YAML:

- The exact code or file change to make.
- The repository population: specific repos, orgs, languages, file presence, package manifests, symbols, imports, or content patterns.
- Whether the change runs once per repository or once per workspace inside monorepos.
- The execution environment needed for `steps`: container image, package manager, formatter, codemod tool, or local script.
- The desired changeset metadata: branch name, commit message, title, body, and publish state.

Ask one narrow clarification only if missing information materially changes the query, command, or publication behavior. If publication is unspecified, use `published: false`.

### 2. Design the repository selection strategy

Choose one or more `on` entries:

- Use `repositoriesMatchingQuery` when targeting repos by code, file names, language, metadata, or repo patterns.
- Use explicit `repository` entries when the target repositories are known.
- Add `branch` or `branches` only when the user explicitly needs non-default branches.
- Use `workspaces` when the same repository can contain multiple independent projects and the steps should run per project root.

For new specs, prefer `version: 2`. In version 2, `on.repositoriesMatchingQuery` defaults to keyword search unless the query explicitly includes another pattern type.

### 3. Validate Code Search queries with Sourcegraph MCP tools

Validate queries before finalizing the spec:

1. Use `mcp__sourcegraph__keyword_search` for exact strings, imports, filenames, package names, config keys, or likely final `repositoriesMatchingQuery` candidates.
2. Use `mcp__sourcegraph__nls_search` only when exact terms are unknown; convert the task to 2-5 meaningful keywords first.
3. Use `mcp__sourcegraph__list_repos` for repo-name discovery when the user names an org or repository imprecisely.
4. Use `mcp__sourcegraph__read_file` on representative matches to confirm the planned change and command are appropriate.
5. Use `mcp__sourcegraph__evaluator` when you must count, aggregate, or cross-reference more results than a single search response can safely show.

Record enough evidence to explain why the query is correct: representative repositories, matching files, and known exclusions.

### 4. Query construction rules

Use Sourcegraph Code Search syntax deliberately:

- Scope repositories with `repo:<regexp>` and exclusions with `-repo:<regexp>`.
- Anchor exact repository regexes with `^` and `$` when targeting one repo or org boundary.
- Use `lang:<language>` or `language:<language>` for language-specific code.
- Use `file:<regexp>` for path or filename constraints.
- Use `type:path` when the query should match filenames rather than file contents.
- Use `repo:has.path(<regexp>)` when repository inclusion depends on a file existing anywhere in the repo.
- Use `repo:has.commit.after(<date>)` to avoid stale repos when freshness matters.
- Use `archived:yes` or `fork:yes` only when the user wants archived repos or forks included.
- Use `count:` only for validation searches, not in the final batch spec query unless there is a specific reason.
- Use `patterntype:regexp` only when regex matching is required; otherwise prefer keyword queries for predictability.

Avoid overbroad queries such as `repo:github.com/company` with only a common term like `config`, `util`, or `TODO`. Add file, language, import, manifest, or repository predicates until the target set is intentional.

### 5. Draft the batch spec YAML

Use this structure unless the task requires imports, transforms, or advanced workspaces:

```yaml
version: 2
name: short-kebab-case-name
description: |
  Explain what this batch change does and why.

on:
  - repositoriesMatchingQuery: repo:^github\.com/example/ file:package.json "old-package" patterntype:keyword

steps:
  - run: |
      # commands that modify files
      sed -i 's/old-package/new-package/g' package.json
    container: alpine:3

changesetTemplate:
  title: Replace old-package with new-package
  body: |
    Updates package manifests from `old-package` to `new-package`.
  branch: batch-changes/replace-old-package
  commit:
    message: Replace old-package with new-package
  published: false
```

When the change needs per-project execution inside monorepos, add `workspaces` and make the branch unique per workspace:

```yaml
workspaces:
  - rootAtLocationOf: package.json
    in: '*'

changesetTemplate:
  branch: ${{ join_if "-" "batch-changes/update-package" (replace steps.path "/" "-") }}
```

### 6. Batch spec field guidance

Use these fields intentionally:

- `version`: Use `2` for new specs.
- `name`: Unique within the Sourcegraph namespace; use short kebab case.
- `description`: Markdown explaining intent and scope.
- `on`: Repository selection. Combine query-based and explicit entries only when needed.
- `steps`: Commands run for each matched repository branch or workspace.
- `steps.env`: Non-secret configuration values required by commands.
- `steps.files`: Inline helper files needed by the container, when simpler than complex shell heredocs.
- `steps.outputs`: Values from stdout/stderr used later in templating.
- `workspaces`: Project roots discovered by a root marker file, such as `package.json`, `go.mod`, `pom.xml`, or `Cargo.toml`.
- `changesetTemplate`: PR/MR title, body, branch, commit metadata, and publication policy.
- `changesetTemplate.published`: Default to `false`; may be `true`, `draft`, or glob rules only when requested.
- `changesetTemplate.fork`: Set only when the user explicitly wants fork-based changesets.
- `transformChanges`: Use only when one repository should produce multiple grouped changesets from one execution.
- `importChangesets`: Use only when importing existing code host changesets instead of producing new changes.

### 7. Safety and correctness checks

Before returning the spec, check:

- The query matches the intended repository population and excludes known non-targets.
- Representative matched files actually need the proposed change.
- Commands are deterministic and idempotent where practical.
- Commands fail noisily on unexpected errors (`set -euo pipefail` for shell scripts when supported by the container shell).
- Required formatters or package managers exist in the chosen container image.
- Branch names are unique when using `workspaces` or `transformChanges`.
- The spec does not include secrets, tokens, or user-private credentials.
- `published` is `false` unless the user explicitly asked to publish or draft changesets.

If the local environment has Sourcegraph CLI configured, recommend or run the narrowest relevant preview command only when appropriate:

```sh
src batch preview -f batch-spec.yml
```

Do not claim the spec was accepted by Sourcegraph unless a preview or apply command actually succeeded.

## Output format

When creating a batch spec, return:

- `## Batch spec` with a fenced `yaml` block containing the complete batch spec.
- `## Query validation` with the final query, representative repos/files or aggregate counts, and important exclusions or assumptions.
- `## Preview step` with the recommended `src batch preview -f <file>` command.

If writing a file in a repository, name it according to local conventions when known, commonly `batch-spec.yml` or `batch-spec.yaml`.

## Examples

### Exact repository list

```yaml
version: 2
name: add-editorconfig
description: |
  Adds a shared EditorConfig file to selected repositories.

on:
  - repository: github.com/example/service-a
  - repository: github.com/example/service-b

steps:
  - run: |
      cat > .editorconfig <<'EOF'
      root = true

      [*]
      charset = utf-8
      end_of_line = lf
      insert_final_newline = true
      EOF
    container: alpine:3

changesetTemplate:
  title: Add shared EditorConfig
  body: Adds the standard EditorConfig settings.
  branch: batch-changes/add-editorconfig
  commit:
    message: Add shared EditorConfig
  published: false
```

### Query-based Go import migration

```yaml
version: 2
name: migrate-go-import
description: |
  Replaces imports of `example.com/old/pkg` with `example.com/new/pkg`.

on:
  - repositoriesMatchingQuery: 'lang:go "example.com/old/pkg" patterntype:keyword'

steps:
  - run: |
      set -eu
      grep -rl 'example.com/old/pkg' -- '*.go' | xargs sed -i 's|example.com/old/pkg|example.com/new/pkg|g'
      gofmt -w .
    container: golang:1.22-alpine

changesetTemplate:
  title: Migrate Go import to example.com/new/pkg
  body: |
    Replaces `example.com/old/pkg` imports with `example.com/new/pkg`.
  branch: batch-changes/migrate-go-import
  commit:
    message: Migrate Go import to example.com/new/pkg
  published: false
```

## Common failure modes to avoid

- Writing the batch spec before validating the repository query.
- Using a broad query that matches repositories merely mentioning the target in documentation.
- Forgetting that workspaces can produce multiple changesets per repository and need unique branches.
- Publishing changesets by default.
- Embedding secrets in `steps.env`, `steps.files`, commit messages, or changeset bodies.
- Assuming GNU utilities are present in minimal containers without checking the image.
- Using local-only scripts in `steps.run` without also providing them through the container image, repository, or `steps.files`.
- Reporting that the spec is valid without running `src batch preview` or an equivalent validation.

## References

- Sourcegraph Batch Spec YAML reference: https://sourcegraph.com/docs/batch-changes/batch-spec-yaml-reference
- Sourcegraph Code Search query syntax: https://sourcegraph.com/docs/code-search/queries
