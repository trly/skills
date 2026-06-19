---
name: update-repo-docs
description: "Updates repository documentation by aligning or creating a root README.md, summarizing related repositories and dependencies, and creating CODEOWNERS only when absent. Use when asked to document a repository, refresh README content, explain high-level system connections, or add ownership metadata from contributor history."
---

# Update Repository Docs

Align a repository's root `README.md` with the project's current behavior, include high-level guidance about related repositories and dependencies, and create a `CODEOWNERS` file only when one does not already exist.

## Use this skill when

- Asked to create, update, refresh, or align repository documentation.
- Asked to generate a root `README.md` for an existing repository.
- Asked to explain how a repository fits into a larger system or depends on adjacent repositories.
- Asked to infer support or ownership from repository contributor history.
- Asked to add `CODEOWNERS`, but only if the repository does not already have one.

## Core principle

Prefer repository evidence over guesses. Documentation should describe what the repository currently does, how to install or set it up, how to use it when it is a library, how it connects to important adjacent system components, and where to get support. Ownership metadata must preserve any existing `CODEOWNERS` file.

## Workflow

### 1. Establish the repository root

Work from the repository root unless the user provides another path. Confirm the root with local files such as:

- package manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`, `Gemfile`
- existing docs: `README.md`, `CONTRIBUTING.md`, `docs/`
- CI or build files: `Makefile`, `.github/workflows/`, `Dockerfile`

Do not update nested package READMEs unless the user explicitly asks.

### 2. Inspect existing documentation and project evidence

Read only the files needed to document the project accurately:

- Existing root `README.md`, if present.
- Package manifests and lockfiles for project name, description, dependencies, scripts, and library entrypoints.
- Build/test tooling files such as `Makefile`, task runners, CI workflows, or language-specific config.
- Public API or entrypoint files when needed to determine whether the repo is a library, service, CLI, or app.
- Existing contribution or support files such as `CONTRIBUTING.md`, `SUPPORT.md`, `.github/ISSUE_TEMPLATE`, and `CODEOWNERS`.

Keep existing correct README content when aligning; replace or reorganize only what is needed to satisfy the required sections.

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

### 4. Preserve existing CODEOWNERS

Before generating `CODEOWNERS`, check all common locations:

- `CODEOWNERS`
- `.github/CODEOWNERS`
- `docs/CODEOWNERS`

If any exists, do not create or overwrite another one. Reference the existing file in the README Support section.

If none exists, generate a root `CODEOWNERS` file. Prefer root `CODEOWNERS` for simplicity unless repository conventions clearly require `.github/CODEOWNERS`.

### 5. Explore contributor history for ownership

If local history is shallow or unavailable and Sourcegraph tools are available, use commit search tools to identify recent or frequent contributors for the repository.

Convert contributors to CODEOWNERS handles only when a handle is directly available from existing repository metadata, prior CODEOWNERS examples, or user-provided information. Do not guess GitHub usernames from names or email addresses.

When handles cannot be determined, use a conservative placeholder comment instead of invalid owners:

```text
# TODO: Replace with repository owner handles inferred from contributor history.
* @example/team
```

If a likely organization or team is evident from existing metadata, prefer a team owner such as `@org/team` over individual contributors. Ask the user only if valid owner handles cannot be inferred and generating placeholder ownership would be unhelpful for the task.

### 6. Generate or align README.md

Follow the Make a README structure and include these sections in order:

1. `# Name`
2. `## Description`
3. `## Setup` with installation or setup instructions
4. `## Usage` only if the repository is a library
5. `## System context` when related repositories or dependencies are important to understand the project
6. `## Support` referencing the repository's `CODEOWNERS` file

Use the actual project name in the H1, not the literal word `Name`.

Section guidance:

- **Name**: Use the package name, module name, repository name, or existing README title.
- **Description**: Explain what the project does and who it is for. Keep it factual and concise.
- **Setup**: Include the package manager, language version, install command, bootstrap command, build command, or environment prerequisites supported by repository evidence.
- **Usage**: Include only for libraries. Show the smallest realistic import or API example from public APIs or documented exports. Omit this section for services, CLIs, documentation-only repos, or apps unless the user asks.
- **System context**: Include a concise bullet list or small table of important adjacent repositories, services, libraries, contracts, infrastructure modules, or external dependencies. Explain the relationship and cite repository-relative files when useful.
- **Support**: Point readers to `CODEOWNERS` for ownership and support routing. If support docs or issue templates exist, reference them too.

Do not invent badges, screenshots, roadmaps, license claims, deployment instructions, or API examples that are not supported by repo evidence.

### 7. Keep updates minimal and maintainable

- Preserve useful existing README details when they fit the required structure.
- Remove stale or contradictory content only when repository evidence proves it is wrong.
- Prefer short setup commands over long prose.
- Use fenced code blocks for commands and examples.
- Link repository-relative files with Markdown links, for example `[CODEOWNERS](CODEOWNERS)`.
- Keep system-context guidance high level; link to deeper architecture docs instead of duplicating them.
- Do not create issues, pull requests, tickets, or external docs without explicit confirmation.

### 8. Verify the documentation update

Run the narrowest useful checks:

- Confirm required README sections exist in order.
- Confirm `## Usage` is present only when the repository is a library.
- Confirm `## System context` is present when related repositories or dependencies materially explain the project.
- Confirm the Support section references the actual `CODEOWNERS` path.
- Confirm no existing `CODEOWNERS` file was overwritten.
- Optionally run a Markdown formatter or lint command only if the repository already provides one.

Useful local checks:

```sh
test -f README.md
rg '^# |^## (Description|Setup|Usage|Support)' README.md
test -f CODEOWNERS -o -f .github/CODEOWNERS -o -f docs/CODEOWNERS
```

## Output format

When done, report:

- Files changed.
- Whether README was created or aligned.
- What related repositories or dependencies were inspected for system context.
- Whether CODEOWNERS was preserved or generated, and what contributor evidence was used.
- Verification command and result.

## Important constraints

- Never overwrite an existing `CODEOWNERS` file.
- Never generate CODEOWNERS owners from guessed usernames.
- Do not broaden the task into full docs restructuring.
- Do not expand system-context discovery beyond direct dependencies and adjacent repositories unless requested.
- Do not add unsupported claims or examples to the README.
- Do not create issues, pull requests, or tickets unless explicitly asked.
