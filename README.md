# skills

## Description

This repository is a collection of Agent Skills that guide AI coding agents
through repeatable engineering workflows. Each skill is a self-contained
`SKILL.md` file under `skills/<skill-name>/` with YAML frontmatter (`name`,
`description`, and optionally `allowed-tools`) followed by Markdown instructions
the agent loads on demand.

The skills are aimed at agent and developer-tooling workflows, and several are
built around Sourcegraph Code Search, Deep Search, and Batch Changes:

- **[update-repo-docs](skills/update-repo-docs/SKILL.md)** — Aligns or creates a
  root `README.md`, summarizes related repositories and dependencies, and
  creates `CODEOWNERS` only when absent.
- **[create-batch-change](skills/create-batch-change/SKILL.md)** — Drafts,
  scopes, and validates Sourcegraph Batch Changes batch spec YAML using Code
  Search queries and Sourcegraph MCP tools.
- **[architecture-alignment](skills/architecture-alignment/SKILL.md)** —
  Evaluates repositories against FINOS architecture-as-code and CALM patterns
  using local artifacts rather than CALM Hub.
- **[research-and-understanding](skills/research-and-understanding/SKILL.md)** —
  Uses Sourcegraph Deep Search for task scoping, implementation planning, and
  review across one or many repositories.

## Setup

No build, package manager, or runtime dependencies are required. The repository
contains only Markdown skill definitions.

```sh
git clone github.com/trly/skills
cd skills
```

Each skill lives in its own directory and is defined by a single `SKILL.md`:

```text
skills/
  update-repo-docs/SKILL.md
  create-batch-change/SKILL.md
  architecture-alignment/SKILL.md
  research-and-understanding/SKILL.md
```

Skills are consumed by an Agent Skills-compatible host: the agent reads the
frontmatter `name` and `description` to decide when a skill applies, then loads
the skill body for detailed instructions. Skills that declare `allowed-tools`
require those tools to be available in the agent environment (see System
context).

## System context

These external dependencies are referenced directly by individual skills and are
needed to fully use them:

| Dependency | Relationship | Used by | Evidence |
| --- | --- | --- | --- |
| Sourcegraph MCP tools (`mcp__sourcegraph__*`) | Skills invoke these tools for code search, Deep Search, and validation | create-batch-change, research-and-understanding | `allowed-tools` in [create-batch-change/SKILL.md](skills/create-batch-change/SKILL.md), [research-and-understanding/SKILL.md](skills/research-and-understanding/SKILL.md) |
| Sourcegraph Batch Changes | Skill produces batch spec YAML and recommends `src batch preview` | create-batch-change | [create-batch-change/SKILL.md](skills/create-batch-change/SKILL.md) |
| FINOS CALM / architecture-as-code | Skill evaluates local CALM schema, model, and pattern files | architecture-alignment | [architecture-alignment/SKILL.md](skills/architecture-alignment/SKILL.md) |
