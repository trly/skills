---
name: architecture-alignment
description: "Evaluates repositories against FINOS architecture-as-code and CALM architectural patterns. Use when asked to assess architecture alignment, discover CALM schema files, or compare implementation repositories to declared architecture without relying on CALM Hub."
---

# Architecture Alignment

Evaluate one or more repositories for adherence to declared architecture-as-code patterns, using local CALM artifacts and repository evidence rather than CALM Hub.

## Use this skill when

- Asked to assess whether a repository follows an architectural design, standard, or pattern.
- Asked to evaluate architecture-as-code conformance across a repository and related repositories.
- Asked to find CALM model, schema, pattern, or architecture files an agent can use locally.
- CALM Hub, remote registries, or centralized architecture catalogs are unavailable or out of scope.

## Core principle

Treat architecture-as-code as executable evidence, not documentation prose. Prefer machine-readable CALM and architecture files first, then corroborate with implementation evidence from source code, deployment manifests, API contracts, and tests.

## Workflow

### 1. Establish the evaluation boundary

Identify:

- The primary repository under assessment.
- Related repositories that implement adjacent services, shared libraries, infrastructure, contracts, or deployment definitions.
- The architecture question: conformance, drift, missing controls, dependency alignment, deployment topology, ownership, resilience, security, or data flow.
- The intended target pattern or standard, if the user supplied one.

If the user does not specify related repositories, infer likely candidates from:

- Workspace files such as `README`, `package.json`, `go.mod`, `pom.xml`, `pyproject.toml`, `Cargo.toml`, `docker-compose.yml`, Helm charts, Terraform modules, CI workflows, and deployment manifests.
- Repository references in documentation, import paths, container image names, service names, OpenAPI specs, AsyncAPI specs, protobuf files, and infrastructure modules.

### 2. Discover local CALM and architecture-as-code artifacts

Assume CALM Hub cannot be used. Search locally and in related repositories for files likely to contain CALM schemas, models, patterns, controls, or architecture metadata.

Start with exact and filename searches for:

- `calm`
- `architecture-as-code`
- `architecture as code`
- `architecture.yml`, `architecture.yaml`, `architecture.json`
- `calm.yml`, `calm.yaml`, `calm.json`
- `*.calm.yml`, `*.calm.yaml`, `*.calm.json`
- `pattern.yml`, `pattern.yaml`, `pattern.json`
- `patterns/`, `architecture/`, `architectures/`, `calm/`, `models/`, `schemas/`, `controls/`, `standards/`, `docs/architecture/`, `.calm/`

Then inspect likely YAML and JSON files for CALM-shaped content. Useful indicators include keys or values such as:

- `$schema`
- `calm`
- `nodes`
- `relationships`
- `interfaces`
- `controls`
- `patterns`
- `metadata`
- `architecture`
- `service`
- `system`
- `flow`
- `deployment`

Also look for JSON Schema references that point to local CALM schemas or vendored FINOS schemas. Do not assume schema URLs are reachable; use URLs as identifiers and local files as evidence.

### 3. Classify discovered artifacts

For each candidate file, classify it as one of:

- **CALM schema**: Defines allowed structure or validation rules, often JSON Schema or YAML/JSON with schema vocabulary.
- **CALM model**: Describes a concrete architecture instance with nodes, relationships, interfaces, metadata, or controls.
- **CALM pattern**: Describes a reusable architecture pattern or expected structural shape.
- **Architecture decision or prose**: ADRs, markdown diagrams, threat models, or design documents.
- **Implementation evidence**: Source code, API specs, deployment manifests, IaC, CI/CD, dependency definitions, or tests.

Prefer CALM schema, model, and pattern files for the alignment baseline. Use prose only when no machine-readable artifact exists or to clarify intent.

### 4. Extract the expected architecture

From CALM artifacts, derive a concise target model:

- Systems, services, components, databases, queues, topics, external dependencies, users, and deployment units.
- Relationships between components, including direction, protocol, data type, trust boundary, and lifecycle coupling when available.
- Interfaces such as REST, GraphQL, gRPC, events, batch jobs, files, or database access.
- Required controls such as authentication, authorization, encryption, audit logging, observability, rate limiting, resilience, approval gates, or data retention.
- Environment expectations such as cloud resources, Kubernetes namespaces, containers, network policies, or Terraform modules.

If multiple CALM files exist, identify whether they are alternatives, versions, overlays, patterns plus instances, or schema plus models. Do not merge them blindly.

### 5. Validate CALM artifacts locally when feasible

If a local schema and model are both available, validate the model against the schema using the repository's existing validation tooling first. Look for commands in `README`, `Makefile`, `package.json`, CI workflows, or scripts.

If no project validator exists, do not install new dependencies unless the user asks. Instead, perform a structural review and state that formal schema validation was not run.

When validation is run, capture:

- Command used.
- Files validated.
- Result.
- Any schema resolution assumptions, especially for remote schema references that were unavailable.

### 6. Compare implementation evidence to the target model

Map source evidence back to the expected architecture:

- Service/component presence: entrypoints, modules, packages, app manifests, container images, Helm charts, Terraform resources.
- Interfaces: route definitions, OpenAPI/AsyncAPI/protobuf files, clients, consumers, producers, SDK usage, ingress definitions.
- Relationships: imports, network clients, service discovery names, environment variables, connection strings, queues, topics, database clients, IAM bindings.
- Controls: middleware, policy definitions, auth libraries, TLS settings, secrets handling, logging/tracing/metrics, retries/timeouts/circuit breakers, schema validation.
- Data and deployment boundaries: database ownership, cross-service database access, network policies, namespaces, account/project boundaries, storage buckets.

Use concrete repository evidence for each finding. Prefer file paths, symbols, config keys, resource names, and test names over broad assertions.

### 7. Identify alignment status

Classify each major expectation as:

- **Aligned**: Implementation evidence satisfies the architectural expectation.
- **Partially aligned**: Some evidence exists, but scope, enforcement, environment, or coverage is incomplete.
- **Diverged**: Implementation contradicts the target architecture.
- **Missing evidence**: The architecture requires it, but the repositories do not show enough evidence.
- **Undeclared implementation**: Implementation contains architectural behavior not represented in CALM artifacts.
- **Ambiguous**: Artifacts or implementation are unclear enough that a human decision is needed.

### 8. Report findings with traceability

Keep the response concise but evidence-backed. Include:

- Architecture baseline files used.
- Related repositories inspected.
- Local CALM schema/model/pattern files found.
- Alignment summary by component, relationship, interface, or control.
- Highest-risk divergences first.
- Practical remediation steps, separating architecture artifact updates from implementation changes.
- Validation performed, or why validation was not possible.

Use this compact format when possible:

```markdown
## Architecture baseline
- CALM model: `path/to/model.yaml`
- CALM schema: `path/to/schema.json`
- Pattern: `path/to/pattern.yaml`

## Alignment summary
| Area | Status | Evidence | Gap |
| --- | --- | --- | --- |
| API gateway routes to service A | Aligned | `infra/gateway.yaml`, `service-a/openapi.yaml` | None |
| Service B owns database B | Diverged | `service-a/src/db.ts` connects to DB B | Cross-service database access |

## Recommended next steps
1. Fix implementation drift: ...
2. Update CALM model for undeclared dependency: ...
3. Add validation to CI: ...
```

## Guidance for finding CALM files without CALM Hub

When CALM Hub is unavailable, use repository-local discovery in this order:

1. Search for filenames and directories containing `calm`, `architecture`, `pattern`, `schema`, or `model`.
2. Search for `$schema` in YAML and JSON files, then inspect schema identifiers for CALM or FINOS references.
3. Search for CALM structural terms such as `nodes`, `relationships`, `interfaces`, and `controls`.
4. Inspect CI workflows and package scripts for validation or generation commands involving CALM, schemas, diagrams, or architecture checks.
5. Inspect docs and ADRs for pointers to generated architecture files or vendored schema locations.
6. If no CALM artifacts exist, state that clearly and fall back to architecture reconstruction from implementation evidence. Recommend adding a local CALM model and schema reference rather than depending on a hub.

## Important constraints

- Do not require CALM Hub access.
- Do not assume remote schema URLs can be fetched.
- Do not treat diagrams or prose as authoritative when conflicting machine-readable CALM artifacts exist.
- Do not modify architecture artifacts or implementation during an assessment unless the user explicitly asks for remediation.
- Do not create issues, pull requests, or tickets without explicit confirmation.
