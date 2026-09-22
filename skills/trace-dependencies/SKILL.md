---
name: trace-dependencies
description: "Traces upstream callers and downstream dependencies across repositories with Sourcegraph, covering library imports, symbol references, REST APIs, and gRPC services. Use for dependency maps, call-chain analysis, integration impact analysis, and identifying API consumers or providers."
allowed-tools:
  - mcp__sourcegraph__evaluator
  - mcp__sourcegraph__find_references
  - mcp__sourcegraph__go_to_definition
  - mcp__sourcegraph__keyword_search
  - mcp__sourcegraph__list_files
  - mcp__sourcegraph__list_repos
  - mcp__sourcegraph__read_file
---

# Trace Dependencies

Trace evidence-backed upstream and downstream dependencies across repositories. Follow actual imports, symbols, routes, RPC definitions, clients, and server handlers rather than inferring relationships from repository names or documentation alone.

## Use this skill when

- Identifying which repositories or components call a library, service, endpoint, or RPC.
- Identifying what APIs, libraries, or services a component calls.
- Tracing a request across REST, gRPC, generated clients, adapters, and handlers.
- Mapping the impact of changing a public symbol, endpoint, protobuf message, or RPC.
- Producing an upstream/downstream dependency map with source evidence.

## Direction is relative to the target

- **Upstream** dependencies call, import, invoke, or send data to the target.
- **Downstream** dependencies are called, imported, invoked, or sent data by the target.

State the target and direction before searching. If the user says “dependencies” without specifying a direction, trace both and label them separately.

```diagram
┌────────────────────┐       ┌────────────────────┐       ┌────────────────────┐
│ Upstream consumers │──────▶│ Target             │──────▶│ Downstream systems │
│ callers / clients  │       │ library / service  │       │ APIs / libraries   │
└────────────────────┘       └────────────────────┘       └────────────────────┘
```

## Evidence standard

Classify every relationship by evidence strength:

| Classification | Required evidence |
| --- | --- |
| **Confirmed** | A call site, import plus symbol use, client invocation, route registration plus handler, RPC client call, or RPC server implementation. |
| **Configured** | A concrete service URL, host, client bean, channel, or dependency declaration exists, but no invocation was found. |
| **Possible** | Only a name, documentation mention, generated artifact, test fixture, or ambiguous string match was found. |

Do not turn a package declaration, generated client, URL constant, or similarly named method into a confirmed runtime call without finding usage. Keep test-only and example-only relationships separate from production code.

## Tool selection

Use the narrowest Sourcegraph tool that can answer the current step:

| Tool | Use |
| --- | --- |
| `list_repos` | Resolve incomplete repository names or enumerate repositories in the active search context. |
| `list_files` | Inspect a known repository layout and locate manifests, API definitions, generated code, clients, or handlers. |
| `keyword_search` | Find exact imports, package coordinates, routes, RPC names, service names, client constructors, configuration keys, or error strings. |
| `go_to_definition` | Follow a known symbol from a call site to its implementation or declaration when precise navigation is available. |
| `find_references` | Find callers and consumers of a known symbol when precise navigation is available. |
| `read_file` | Verify matches in context and inspect the complete call, import, route, handler, or configuration flow. |
| `evaluator` | Exhaustively aggregate, cross-reference, deduplicate, or count results when fixed search result limits are insufficient. |

Use symbol navigation before broad text search when a concrete symbol and definition are known. If `find_references` or `go_to_definition` is unavailable, returns “Symbol not found,” or cannot cross a generated or dynamic boundary, fall back to exact `keyword_search` queries and verify each candidate with `read_file`.

## Workflow

### 1. Define the trace boundary

Record:

- The target repository, package, service, API, route, RPC, or symbol.
- Whether to trace upstream, downstream, or both.
- The repository organization, search context, revision, and environment in scope.
- Whether tests, examples, generated files, vendored code, archived repositories, or forks should count.
- The desired depth: direct dependencies only or a transitive call chain.

Preserve explicit repository and revision scope in every search and file read. If scope is unclear, start with the active Sourcegraph context rather than silently searching unrelated repositories.

### 2. Resolve repositories and entry points

Use `list_repos` when the exact repository name is unknown. Once a repository is known, use `list_files` to locate likely entry points:

- Dependency manifests and lockfiles.
- API specifications, protobuf files, and generated clients.
- HTTP clients, route registries, controllers, handlers, and service adapters.
- Configuration files containing service names, base URLs, ports, or channel targets.

Do not guess file paths. Verify a path exists before calling `read_file`.

### 3. Seed the search with stable identifiers

Prefer identifiers that survive naming differences across repositories:

- Fully qualified import paths and package coordinates.
- Exported type, function, class, interface, or method names.
- Protobuf package, service, RPC, and message names.
- HTTP method plus route path.
- OpenAPI `operationId`, client method, service hostname, or configuration key.

Use `keyword_search` with one to three exact terms and a repository scope. Avoid combining many speculative terms into one query.

### 4. Follow symbols when available

For a known call-site symbol:

1. Call `go_to_definition` with the repository, file path, symbol, and revision when pinned.
2. Read the returned definition with `read_file` to understand whether it is a wrapper, interface, generated client, or implementation.
3. Call `find_references` from the definition to identify consumers.
4. Read representative references to confirm that they are actual calls and determine their direction.
5. Repeat across wrappers only while the next hop remains within the requested depth.

Do not assume a reference is a call. Imports, type annotations, mocks, registration, and construction sites describe different relationships and must be labeled accurately.

### 5. Trace library dependencies

#### Downstream from a consumer

1. Confirm the dependency in a manifest, module file, or build definition.
2. Search for its exact import path or package namespace.
3. Read importing files and identify the imported symbols actually used.
4. Use `go_to_definition` on those symbols when cross-repository navigation is available.
5. Record the call site, resolved declaration or implementation, and whether usage is production, test, build-time, or tooling-only.

#### Upstream to a library

1. Identify stable public symbols and the canonical import path.
2. Use `find_references` for indexed public symbols when available.
3. Search the canonical import path across the requested repository scope to catch languages or builds without precise navigation.
4. Cross-reference imports with actual symbol calls; do not count an unused import, manifest-only declaration, vendored copy, or lockfile entry as a confirmed caller.

### 6. Trace REST APIs

#### Downstream clients

Search for combinations of:

- HTTP client calls and request builders.
- Typed or generated API client methods.
- Route fragments, `operationId` values, service base URLs, and configuration keys.
- Authentication, serialization, retry, or adapter code surrounding the request.

Read enough context to capture the HTTP method, assembled path, request type, response type, target configuration, and caller. Dynamic base URLs or paths should be followed through definitions and configuration rather than guessed.

#### Upstream servers and consumers

1. Find route registration or framework annotations for the method and path.
2. Follow the handler symbol with `go_to_definition` when available.
3. Read the handler and its downstream calls.
4. To find external consumers, search exact route fragments, OpenAPI client method names, `operationId` values, and generated client symbols across the scoped repositories.

A shared path string alone is only possible evidence. Confirm the HTTP method and surrounding client invocation before marking a consumer as confirmed.

### 7. Trace gRPC APIs

1. Find the `.proto` definition and record its package, service, RPC, request, and response types.
2. Find generated client and server symbols, accounting for language-specific naming conventions.
3. For downstream callers, find client construction or channel setup and the concrete RPC invocation.
4. For the provider, find server registration and the implementing handler method.
5. Follow handler downstream calls and message conversions when the requested depth includes internal processing.
6. Search the fully qualified service name and RPC name across repositories to catch clients where precise references do not cross generated-code boundaries.

Generated stubs prove capability, not use. Confirm an RPC invocation or server registration before reporting a runtime relationship.

### 8. Aggregate exhaustive results when needed

Use `evaluator` when the answer requires complete counts, joining multiple searches, or reading every candidate file. Typical uses include:

- Intersecting repositories that import a package with files that call a public symbol.
- Deduplicating clients found through route strings, generated method names, and configuration keys.
- Grouping references by repository, source set, or production/test classification.
- Detecting `limitHit` and narrowing searches until coverage is complete.

Within evaluator scripts, scope searches tightly by repository, file type, stable identifier, and revision. Use `source.read_file` for candidates whose classification depends on multi-line context. Check `stats.limitHit`; never describe capped results as exhaustive.

### 9. Verify every edge

For each reported edge, read the relevant source and capture:

- Caller repository, path, symbol, and line range.
- Callee repository, path, symbol, and line range when available.
- Protocol or dependency type: import, in-process call, REST, gRPC, or configuration.
- Direction relative to the target.
- Evidence classification and runtime scope.

Preserve the revision from search or symbol results when reading files. If symbol navigation and text search disagree, inspect both paths and explain the discrepancy instead of choosing the more convenient result.

## Reporting format

```markdown
## Dependency trace: <target>

Scope: `<repositories/context and revision>`
Depth: direct / transitive to <boundary>

### Upstream

| Caller | Relationship | Target | Classification | Evidence |
| --- | --- | --- | --- | --- |
| repo/path:Symbol | REST `POST /v1/orders` | orders-api | Confirmed | client call at line 42; route at line 18 |

### Downstream

| Source | Relationship | Dependency | Classification | Evidence |
| --- | --- | --- | --- | --- |
| repo/path:Symbol | gRPC `Inventory.Reserve` | inventory-service | Confirmed | RPC invocation at line 77; handler at line 31 |

### Call chain

`consumer → target endpoint/handler → adapter → downstream API`

### Coverage and uncertainty

- Repositories searched: <count or explicit list>
- Generated/test/example code treatment: <included/excluded and labels>
- Incomplete areas: <result limits, inaccessible repos, dynamic dispatch, runtime discovery, or none>
```

Link or cite exact repository paths and line ranges. Keep confirmed relationships separate from configured and possible relationships. For transitive traces, show each independently verified edge rather than collapsing several inferred hops into one arrow.

## Important constraints

- This skill is read-only unless the user separately asks for code changes.
- Do not claim runtime communication from naming, configuration, or generated code alone.
- Do not claim exhaustive coverage when searches are capped, repositories are inaccessible, or dynamic discovery prevents static resolution.
- Do not include archived repositories, forks, tests, fixtures, examples, or generated code in production counts without stating that policy.
- Do not create issues, pull requests, or batch changes without explicit user approval.
