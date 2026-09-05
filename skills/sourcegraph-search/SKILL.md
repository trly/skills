---
name: sourcegraph-search
description: Use src-cli to search Sourcegraph code with Sourcegraph query syntax. Use when asked to search Sourcegraph, find code across repositories, build Sourcegraph queries, or use repo/file/content filters and predicates.
---

# Sourcegraph Search with `src-cli`

Use this skill when the user asks to search Sourcegraph or wants help constructing a Sourcegraph code-search query. Prefer `src search` over ad-hoc web searches when Sourcegraph has the relevant indexed code.

## First: verify CLI access

1. Check that `src` is available:

   ```bash
   command -v src
   src search -h
   ```

2. If authentication or endpoint errors occur, ask the user for the Sourcegraph instance or have them log in:

   ```bash
   src login https://sourcegraph.com
   # or an enterprise instance:
   src login https://sourcegraph.example.com
   ```

3. Use a custom endpoint if needed:

   ```bash
   src -endpoint https://sourcegraph.example.com search 'repo:example pattern'
   ```

## Running searches

Basic commands:

```bash
src search 'repo:github.com/sourcegraph/sourcegraph lang:go NewHandler'
src search -json 'repo:github.com/sourcegraph/sourcegraph file:\.go$ content:"NewHandler"'
src search -stream -json 'repo:github.com/sourcegraph/sourcegraph TODO count:all'
```

Important CLI details:

- Always quote the full Sourcegraph query for the shell.
- If the query begins with a negative filter, use `--` so `src` does not parse it as a CLI flag:

  ```bash
  src search -- '-repo:github.com/foo/bar error'
  ```

- Use `-json` for machine-readable output; combine with `jq` if available.
- Use `-stream` for large searches. Streaming supports fewer flags, but can return results progressively.
- Use `count:N` or `count:all` in the Sourcegraph query when completeness matters.
- Use `timeout:15s` or another Go duration when broad searches need more time; Sourcegraph commonly caps this at 1 minute.

## Regex syntax: RE2, not PCRE

Sourcegraph regular expressions use **RE2 syntax** anywhere a regex is accepted.

Be explicit about this when writing or reviewing queries:

- Good: `file:\.(go|ts)$`, `repo:^github\.com/sourcegraph/sourcegraph$`, `content:"foo.*bar"`
- Avoid PCRE-only features such as lookahead/lookbehind and backreferences. Rewrite with RE2-compatible expressions or boolean query structure instead.
- Regex matching is generally unanchored unless anchors are provided. Use `^` and `$` when you need exact path/repo matching.

## Core query model

A typical query has:

- Search patterns: terms or regexes to find, such as `println`, `foo.*bar`, or `"foo bar"`
- Parameters/filters: `repo:`, `file:`, `lang:`, `content:`, `type:`, etc.
- Boolean operators: `AND`, `OR`, `NOT`, and parentheses. Lowercase `and`/`or` work too. Prefer parentheses when mixing operators.

Examples:

```text
repo:github.com/sourcegraph/sourcegraph rtr AND newRouter
repo:github.com/sourcegraph/sourcegraph (file:\.go$ OR file:\.ts$) content:"TODO"
```

## Filters applicable to all searches

Use these filters often:

| Filter | Use |
| --- | --- |
| `repo:regexp-pattern` / `r:` | Include repos whose path matches the RE2 regex. |
| `-repo:regexp-pattern` / `-r:` | Exclude repos. |
| `repo:regexp-pattern@rev` | Search a repo at a revision. Equivalent to `repo:regexp-pattern rev:rev`. |
| `rev:revision-pattern` | Search a revision; only with `repo:` and only once. |
| `file:regexp-pattern` / `f:` | Include files whose full path matches the RE2 regex. |
| `-file:regexp-pattern` / `-f:` | Exclude files by path. |
| `content:"pattern"` | Set the content search pattern explicitly, useful for literals that look like filters. Escape literal `\` as `\\` inside quotes. |
| `-content:"pattern"` | Exclude files whose content matches. |
| `lang:go` / `language:go` | Include a language. |
| `-lang:typescript` | Exclude a language. |
| `type:file` | Search file contents only. |
| `type:path` | Search filenames/paths only. |
| `type:symbol` | Search symbols. |
| `select:repo`, `select:file`, `select:content`, `select:file.directory`, `select:file.owners` | Convert/deduplicate returned result types. |
| `case:yes` | Make matching case-sensitive. |
| `fork:yes` / `fork:only` | Include forks or search only forks. Forks are excluded by default. |
| `archived:yes` / `archived:only` | Include archived repos or search only archived repos. Archived repos are excluded by default. |
| `count:N` / `count:all` | Return more results or wait for all results. |
| `timeout:15s` | Increase search timeout. |

## Repository search

Repository scoping is usually the most important part of a useful query.

Examples:

```bash
src search 'repo:gorilla/mux testroute'
src search 'repo:^github\.com/sourcegraph/sourcegraph$@v3.14.0 mux'
src search 'repo:sourcegraph/sourcegraph rev:v5.0.0 get_embeddings'
src search 'repo:docker repo:registry'
src search 'repo:docker OR repo:registry'
```

Notes:

- `repo:` matches repository paths with RE2 regexes. Anchor exact repos: `repo:^github\.com/org/repo$`.
- Multiple `repo:` filters are intersected: `repo:docker repo:registry` means repo path contains both.
- Use `OR` for alternatives: `repo:docker OR repo:registry`.
- A query with only `repo:` filters lists matching repositories.
- Revisions can be branches, tags, or commit hashes:
  - `repo:github.com/myteam/abc@branch`
  - `repo:github.com/myteam/abc@1735d48`
  - `repo:github.com/myteam/abc@3.15`
  - `repo:github.com/myteam/abc@branch:1735d48:3.15`
- Limit revision names with `refs/heads/...` or `refs/tags/...` when necessary.
- Use revision globs with `@*refs/heads/*` or `@*refs/tags/*`; negate with `*!`, e.g. `@*refs/heads/*:*!refs/heads/release*`.

## Content search

Use content searches when matching inside file bodies.

```bash
src search 'type:file repo:^github\.com/sourcegraph/about$ website'
src search 'repo:sourcegraph content:"repo:sourcegraph"'
src search 'file:Dockerfile alpine -content:alpine:latest'
src search 'repo:myorg/ lang:go content:"fmt\.Errorf"'
```

Notes:

- `type:file` restricts search terms to file contents, not filenames.
- `content:"..."` is best when the literal search text could be parsed as query syntax, such as `repo:sourcegraph`.
- `-content:"..."` excludes files containing the pattern.

## File/path search

Use file filters to scope content searches or discover filenames.

```bash
src search 'repo:myorg/ file:\.js$ httptest'
src search 'repo:myorg/ file:^README\.md$'
src search 'repo:myorg/ type:path registry'
src search 'repo:myorg/ file:(internal/repos)|(internal/gitserver) content:"TODO"'
```

Notes:

- `file:` matches the full path with RE2 and is unanchored by default.
- For exact file names, anchor: `file:^README\.md$`.
- `type:path` restricts terms to filenames/paths only.
- When combining file alternatives with boolean logic, prefer clear parentheses: `(file:internal/repos OR file:internal/gitserver) content:"TODO"`.

## Built-in repo predicates

Use repo predicates to include repositories only if the repo has some property.

```text
repo:has.meta(team:sourcegraph)
repo:has.meta(team:/[source]{5}graph/)
repo:has.meta(language)
repo:has.file(path:CHANGELOG content:fix)
repo:contains.file(path:CHANGELOG content:fix)
repo:has.path(README)
repo:contains.path(README)
repo:github\.com/sourcegraph/.*$ repo:has.content(TODO)
repo:contains.content(TODO)
repo:has.topic(code-search)
repo:has.commit.after(1 month ago)
repo:contains.commit.after(1 month ago)
repo:has.description(go package)
```

Key points:

- `repo:has.meta(...)` searches repos with metadata by key-value pair, key with any value, or key with no value. Slash-delimited regexes are supported for key/value patterns.
- `repo:has.file(path:... content:...)` requires a matching path/content combination in the repository.
- `repo:has.path(...)` requires any matching file path.
- `repo:has.content(...)` requires matching file content somewhere in the repo.
- `repo:has.topic(...)` works for GitHub/GitLab topics.
- `repo:has.commit.after(...)` helps filter out stale repositories; date formats like `yesterday` or `1 month ago` are accepted.

## Built-in file predicates

Use file predicates to include files only if the file has some property.

```text
file:has.content(test)
file:contains.content(test)
file:has.owner()
-file:has.owner()
file:has.owner(alice@sourcegraph.com)
file:has.contributor(alice@sourcegraph.com)
```

Key points:

- `file:has.content(...)` filters to files containing content matching the RE2 regex.
- `file:has.owner(...)` filters to files owned by the given owner. Empty `file:has.owner()` means any owner; `-file:has.owner()` means no owner.
- `file:has.contributor(...)` filters by contributor name or email matching the RE2 regex.

## Query construction workflow

1. Start with the smallest plausible `repo:` scope.
2. Add `file:`/`lang:` filters to reduce noise.
3. Add the content pattern, preferably with `content:"..."` if it contains punctuation or could look like a filter.
4. Add `type:file`, `type:path`, or `select:*` when the desired result shape is clear.
5. Add `count:all` or `count:N` only when needed.
6. Run with `src search -json` when you need to parse, summarize, or post-process results.
7. If a regex fails unexpectedly, check for RE2 incompatibilities and escaping at both the shell and Sourcegraph-query layers.
