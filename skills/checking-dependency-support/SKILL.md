---
name: checking-dependency-support
description: "Checks dependency and product support lifecycle status using the endoflife.date API. Use when asked whether a dependency version is still supported, what versions are receiving security updates, when a version reaches end-of-life, or whether an upgrade is needed."
allowed-tools:
  - shell_command
  - shell_command_status
---

# Checking Dependency Support

Query the [endoflife.date](https://endoflife.date) API to determine which dependency versions are still receiving support, which have reached end-of-life, and when supported versions will expire.

## Use this skill when

- Asked whether a specific dependency version is still supported or has reached EOL.
- Asked which versions of a product are currently receiving security or maintenance updates.
- Asked when a dependency version will reach end-of-life.
- Asked whether a dependency upgrade is necessary based on support status.
- Reviewing a dependency manifest and flagging versions that are past or approaching end-of-life.
- Asked to find the latest version of a product or its release cycle information.

## Do not use this skill when

- The question is about a dependency's features or changelog rather than its support lifecycle.
- The product is not listed on endoflife.date (check first with `scripts/check-support.sh --search <term>`).
- The user already knows the EOL status and wants implementation help for an upgrade.

## Core principle

Use the endoflife.date API as the single source of truth for support lifecycle data. Query it directly with `curl` or the bundled script, parse the structured response, and report support status with exact dates. Never guess EOL dates from general knowledge — always confirm against the API.

```diagram
╭──────────────╮     ╭──────────────────────╮     ╭───────────────────╮
│ Dependency   │────▶│ endoflife.date API   │────▶│ Support status    │
│ name/version │     │ /products/{product}  │     │ report with dates │
╰──────────────╯     ╰──────────┬───────────╯     ╰───────────────────╯
                                │
                                ▼
                     ╭──────────────────────╮
                     │ Release cycles:      │
                     │ - isMaintained       │
                     │ - isEol / eolFrom    │
                     │ - isLts              │
                     │ - isEoas / eoasFrom  │
                     ╰──────────────────────╯
```

## API overview

Base URL: `https://endoflife.date/api/v1`

Key endpoints:

| Endpoint | Purpose |
| --- | --- |
| `GET /products` | List all tracked products (summary only) |
| `GET /products/{product}` | Get full product details including all release cycles |
| `GET /products/{product}/releases/{release}` | Get a specific release cycle |
| `GET /products/{product}/releases/latest` | Get the latest release cycle |
| `GET /categories/{category}` | List products in a category |
| `GET /tags/{tag}` | List products with a tag |

The full response schema for `ProductRelease` and `ProductDetails` is in [reference/api-reference.md](reference/api-reference.md). Load it when you need to interpret fields beyond the common ones listed below.

## Key fields in a release cycle

Each release cycle in the `releases` array of a `ProductDetails` response carries these support-status fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | Release cycle name (e.g. `"22.04"`, `"3.12"`) |
| `isMaintained` | boolean | Whether this cycle still has any level of support (active, LTS, or extended) |
| `isEol` | boolean | Whether the cycle has reached end-of-life |
| `eolFrom` | date\|null | EOL date; `null` when unknown |
| `isLts` | boolean | Whether the cycle receives long-term support |
| `ltsFrom` | date\|null | Start of LTS phase |
| `isEoas` | boolean\|absent | Whether active support has ended (absent if the product has no active-support phase) |
| `eoasFrom` | date\|null\|absent | End of active support date |
| `isEoes` | boolean\|null\|absent | Whether extended support has ended |
| `eoesFrom` | date\|null\|absent | End of extended support date |
| `isDiscontinued` | boolean\|absent | Whether the cycle is discontinued (mainly hardware) |
| `latest` | object\|null | Latest version in this cycle with `name`, `date`, `link` |

### Support status classification

Use these fields to classify each version:

| Status | Condition |
| --- | --- |
| **Active support** | `isMaintained` is `true` AND `isEoas` is `false` (or absent) AND `isEol` is `false` |
| **Maintenance / Security only** | `isEoas` is `true` AND `isEol` is `false` AND `isMaintained` is `true` |
| **Extended support** | `isEoes` is `false` or `null` AND `isEol` is `true` (when the product has an extended-support phase) |
| **End-of-life** | `isEol` is `true` AND `isEoes` is `true` (or absent) |
| **Discontinued** | `isDiscontinued` is `true` |

When `isEoas`, `isEoes`, or `isDiscontinued` are absent from the response, the product does not have that support phase — skip that classification.

## Workflow

### 1. Identify the product

Determine the endoflife.date product name. Common mappings:

| Dependency | Product name |
| --- | --- |
| Python | `python` |
| Node.js | `nodejs` |
| Ubuntu | `ubuntu` |
| PostgreSQL | `postgresql` |
| Redis | `redis` |
| Nginx | `nginx` |
| Kubernetes | `kubernetes` |

When unsure, search for the product:

```sh
scripts/check-support.sh --search <term>
```

This queries `GET /products` and filters by name/label. The product `name` field is the slug used in API paths.

### 2. Fetch product details and release cycles

Get all release cycles for the product:

```sh
scripts/check-support.sh <product>
```

This fetches `GET /products/{product}`, extracts each release cycle, and prints a table with support status, EOL dates, LTS flags, and latest version. The script handles JSON parsing with `jq` and degrades gracefully when `jq` is not installed.

Alternatively, call the API directly:

```sh
curl -sS "https://endoflife.date/api/v1/products/<product>" | jq '.result.releases[]'
```

### 3. Check a specific version

To check whether a specific version is still supported, match the version to a release cycle. Release cycle names are usually the major or minor version prefix (e.g. `3.12` for Python 3.12.x, `22.04` for Ubuntu 22.04.x).

```sh
scripts/check-support.sh <product> <version>
```

This fetches the product, finds the matching release cycle, and prints the support status with dates. If the version does not match any cycle exactly, the script searches for a prefix match (e.g. `3.12.5` matches cycle `3.12`).

### 4. Get the latest release cycle

```sh
scripts/check-support.sh --latest <product>
```

This fetches `GET /products/{product}/releases/latest` and prints the latest release cycle information.

### 5. Interpret and report

When reporting results, include:

- The product label and the product name used for the query.
- For each release cycle: cycle name, support status, LTS flag, EOL date (or "EOL" if already past), latest version in the cycle.
- A clear recommendation: which versions are safe to use, which should be upgraded, and which are past EOL.
- The date the data was generated (`generated_at` from the API response) so the user knows the freshness.

## Reporting format

```markdown
## Support status: <Product Label>

Data source: endoflife.date API (generated <generated_at>)

| Cycle | Status | LTS | Latest | EOL Date |
| --- | --- | --- | --- | --- |
| 22.04 | Active support | ✅ | 22.04.5 | 2027-04-01 |
| 24.04 | Active support | ✅ | 24.04.2 | 2029-04-01 |
| 20.04 | Maintenance only | ✅ | 20.04.6 | 2025-04-02 |
| 18.04 | End-of-life | ❌ | 18.04.6 | 2023-05-31 |

## Recommendation
- **Currently supported**: 24.04, 22.04, 20.04 (maintenance only)
- **Upgrade needed**: 18.04 reached EOL on 2023-05-31
- **Latest LTS**: 24.04
```

When checking a single version, use:

```markdown
## <Product> <version>: <status>

- LTS: yes/no
- End of active support: <date or "n/a">
- End of life: <date or "already EOL">
- Latest in this cycle: <version>
- Recommendation: <safe to use / upgrade to <version> / past EOL, upgrade immediately>
```

## Working with dependency manifests

When asked to review a dependency manifest (e.g. `package.json`, `pyproject.toml`, `go.mod`, `Dockerfile`):

1. Read the manifest to extract dependency names and versions.
2. Map each dependency to its endoflife.date product name. Use `--search` when unsure.
3. For each dependency, run `scripts/check-support.sh <product> <version>` or fetch the product details.
4. Classify each dependency's version using the support status table above.
5. Report a summary table with all dependencies and flag any that are EOL or approaching EOL.

Do not modify the manifest unless the user explicitly asks. Report-only is the default.

## Error handling

- **404**: The product name is wrong. Search for the correct name with `--search`.
- **429**: Rate limited. Wait and retry. The API may return a `Retry-After` header.
- **301**: The product was renamed. Follow the redirect (curl does this by default with `-L`).
- **jq not installed**: The script falls back to raw JSON output. Install `jq` for formatted output, or parse the JSON manually.

## Important constraints

- Always query the API for current data — never rely on memorized EOL dates.
- Report the `generated_at` timestamp so the user knows data freshness.
- Do not modify dependency manifests or lockfiles unless the user explicitly asks.
- Do not create issues, pull requests, or tickets without explicit confirmation.
- When a product is not found on endoflife.date, state that clearly and suggest checking the product's own support page.
- The API may add new fields over time; ignore undocumented fields rather than relying on them.
