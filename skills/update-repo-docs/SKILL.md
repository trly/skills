---
name: update-repo-docs
description: "Updates repository documentation by aligning or creating a root README.md, summarizing related repositories and dependencies, and creating CODEOWNERS only when absent. Use when asked to document a repository, refresh README content, explain high-level system connections, or add ownership metadata from contributor history."
---

# Update Repository Docs

Align the repository's root `README.md` with the project's current behavior, and include high-level guidance on related repositories and dependencies.
Create or update an AGENTS.md file with the in-use agents initialization functionality. Keep AGENTS.md files short.

## Use this skill when

- Asked to create, update, refresh, or align repository docs.
- Asked to generate a root `README.md` for an existing repository.
- Asked to explain how a repository fits into a larger system or depends on adjacent repositories.
- Asked to infer support or ownership from repository contributor history.

## Core principle

Prefer repository evidence over guesses. docs should describe what the repository currently does, how to install or set it up, how to use it as a library, how it connects to important adjacent system components, and where to get support.

Stale repositories should not be updated; only update those with recent commit activity within the last 60 days.

## Workflow

### 1. Establish the repository root

Work from the repository root unless the user provides another path. Confirm the root with local files such as:

- package manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`, `Gemfile`
- existing docs: `README.md`, `CONTRIBUTING.md`, `docs/.`
- CI or build files: `Makefile`, `.github/workflows/`, `Dockerfile`

Do not update the READMEs of nested packages unless the user explicitly asks.

#### Ensure the workspace has enough git history

This skill needs access to git history to identify recent, frequent changes. When running inside a Sourcegraph Batch Changes workspace, the batch spec controls how much history is fetched into the workspace.

In **batch spec v3**, this is configured at the top level via `checkout.fetchDepth`:

```yaml
version: 3
checkout:
  fetchDepth: 0   # 0 = full git history; 1 = shallow (default); N = N most recent commits
```

| Value | Behavior |
|---|---|
| `1` (default) | Shallow clone — only the target commit. Not enough to infer ownership from history. |
| `0` | Full git history. Required for contributor-based CODEOWNERS inference. |
| `N > 1` | The N most recent commits. Useful when only recent contributors matter. |

When the workspace was checked out with the default shallow depth, commands like `git log` return only the tip commit, so contributor-based ownership inference is not possible. In that case:

- Ask the user to re-run with `checkout.fetchDepth: 0` (or a large `N`) so the workspace has enough history. The `checkout` key is reserved for the batch change agent and is only available in v3 batch specs.
- If re-running is not an option, fall back to signals that do not require history (existing metadata)

Separately, the `workspaces.onlyFetchWorkspace` field controls **which directories** are downloaded, not history depth.

### 2. Inspect existing docs and project evidence

Read only the files needed to document the project accurately:

- Existing root `README.md`, if present.
- Package manifests and lockfiles for project name, description, dependencies, scripts, and library entrypoints.
- Build/test tooling files such as `Makefile`, task runners, CI workflows, or language-specific config.
- Public API or entrypoint files, when needed, to determine whether the repo is a library, service, CLI, or app.
- Existing contribution or support files such as `CONTRIBUTING.md`, `SUPPORT.md`, `.github/ISSUE_TEMPLATE`, and `CODEOWNERS`.

Keep the existing README content intact when aligning; replace or reorganize only what is needed to satisfy the required sections.

### 3. Explore related repositories and dependencies

Identify high-signal dependencies and adjacent repositories so the README can explain how the project fits into the larger system. Keep this exploration bounded to direct relationships unless the user asks for a deeper architecture map.

Look for:

- Internal package, module, or import paths in manifests and source files.
- Service clients, SDKs, generated API clients, protobuf/OpenAPI/AsyncAPI references, queue or topic names, database schemas, and shared libraries.
- Docker Compose, Helm, Terraform, Kubernetes, CI, or deployment files that name upstream or downstream services.
- Repository URLs, organization-scoped package names, Git submodules, vendored modules, and workspace references.
- Existing architecture, ADR, or system overview docs that name adjacent repositories or components.

When another repository appears important and is available locally or through Sourcegraph, inspect only enough evidence to identify its role and relationship to the current repository. Capture:

- Component or repository name.
- Relationship direction: consumes, provides, publishes to, subscribes to, embeds, deploys, or shares code with.
- Integration mechanism: package dependency, API call, event stream, database, CLI, container image, IaC module, or generated contract.
- Evidence path or manifest key supporting the relationship.

Do not turn README generation into a full architecture assessment. Summarize direct, user-relevant relationships at a high level and avoid speculative transitive dependencies.

### 4. Generate or align README.md

Follow the Make a README structure and include these sections in order:

1. `# Name`
2. `## Description`
3. `## Setup` with installation or setup instructions
4. `## Usage` only if the repository is a library
5. `## System context` when related repositories or dependencies are important to understand the project

Use the actual project name in the H1, not the literal word `Name`.

Section guidance:

- **Name**: Use the package name, module name, repository name, or existing README title.
- **Description**: Explain what the project does and who it is for. Keep it factual and concise.
- **Setup**: Include the package manager, language version, install command, bootstrap command, build command, or environment prerequisites supported by repository evidence.
- **Usage**: Include only for libraries. Show the smallest realistic import or API example from public APIs or documented exports. Omit this section for services, CLIs, documentation-only repos, or apps unless the user asks.
- **System context**: Include a concise bullet list or small table of important adjacent repositories, services, libraries, contracts, infrastructure modules, or external dependencies. Explain the relationship and cite repository-relative files when useful.

Do not invent badges, screenshots, roadmaps, license claims, deployment instructions, or API examples that are not supported by repo evidence.

### 7. Keep updates minimal and maintainable

- Preserve useful existing README details when they fit the required structure.
- Remove stale or contradictory content only when repository evidence proves it is wrong.
- Prefer short setup commands over long prose.
- Use fenced code blocks for commands and examples.
- Link repository-relative files with Markdown links
- Keep system-context guidance at a high level; link to deeper architecture docs instead of duplicating them.
- Do not create issues, pull requests, tickets, or external docs without explicit confirmation.

### 8. Verify the docs update

Run the narrowest useful checks:

- Confirm required README sections exist in order.
- Confirm `## Usage` is present only when the repository is a library.
- Confirm `## System context` is present when related repositories or dependencies materially explain the project.
- Optionally run a Markdown formatter or lint command only if the repository already provides one.

Useful local checks:

```sh
test -f README.md
rg '^# |^## (Description|Setup|Usage|Support)' README.md
test -f AGENTS.md
```

## Output format

When done, report:

- Files changed.
- Whether the README was created or aligned.
- Whether AGENTS.md was created or aligned.
- What related repositories or dependencies were inspected for system context?
- Verification command and result.

## Important constraints

- Do not broaden the task into full docs restructuring.
- Do not expand system-context discovery beyond direct dependencies and adjacent repositories unless requested.
- Do not add unsupported claims or examples to the README.
- Do not create issues, pull requests, or tickets unless explicitly asked.
