# endoflife.date API Reference

Base URL: `https://endoflife.date/api/v1`

All responses are JSON. The API is backward compatible: follow 301 redirects, tolerate new fields, and tolerate new enum values.

## Endpoints

### GET /products

Lists all tracked products. Returns a `ProductListResponse` with summary objects.

```sh
curl -sS "https://endoflife.date/api/v1/products" | jq '.result[] | {name, label, category}'
```

### GET /products/full

Lists all products with full details including release cycles. This is a large response — prefer `/products` for summaries and `/products/{product}` for a single product.

### GET /products/{product}

Returns full product details including all release cycles.

```sh
curl -sS "https://endoflife.date/api/v1/products/python" | jq '.result.releases[]'
```

### GET /products/{product}/releases/{release}

Returns a single release cycle for a product. The `{release}` path parameter is the cycle name (e.g. `3.12`).

```sh
curl -sS "https://endoflife.date/api/v1/products/python/releases/3.12" | jq '.result'
```

### GET /products/{product}/releases/latest

Returns the latest release cycle for a product.

```sh
curl -sS "https://endoflife.date/api/v1/products/python/releases/latest" | jq '.result'
```

### GET /categories/{category}

Lists all products in a category (e.g. `os`, `db`, `lang`, `app`, `server`, `framework`).

### GET /tags/{tag}

Lists all products with a given tag.

### GET /identifiers/{identifier_type}

Lists all identifiers for a given type (e.g. `purl`). Each entry references its related product.

## Response schemas

### ProductListResponse

```json
{
  "schema_version": "1.0.0",
  "generated_at": "2025-01-15T12:00:00+01:00",
  "total": 200,
  "result": [ProductSummary, ...]
}
```

### ProductSummary

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Product slug (used in API paths) |
| `label` | string | Display name |
| `aliases` | string[] | Alternative names (empty if none) |
| `category` | string | Category slug |
| `tags` | string[] | Tags (always includes the category) |
| `uri` | string | Link to full product details |

### ProductResponse

```json
{
  "schema_version": "1.0.0",
  "generated_at": "2025-01-15T12:00:00+01:00",
  "last_modified": "2025-01-10T08:00:00+01:00",
  "result": ProductDetails
}
```

### ProductDetails

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Product slug |
| `label` | string | Display name |
| `aliases` | string[] | Alternative names |
| `category` | string | Category slug |
| `tags` | string[] | Tags |
| `versionCommand` | string\|null | Command to check installed version |
| `identifiers` | Identifier[] | Known identifiers (purl, cpe, repology) |
| `labels` | object | Phase labels: `eol` (required), `eoas`, `eoes`, `discontinued` |
| `labels.eol` | string | Label for the pre-EOL phase |
| `labels.eoas` | string\|null | Label for the pre-end-of-active-support phase |
| `labels.eoes` | string\|null | Label for the pre-end-of-extended-support phase |
| `labels.discontinued` | string\|null | Label for discontinuation (mainly hardware) |
| `links` | object | Links: `html` (required), `icon`, `releasePolicy` |
| `links.html` | string | endoflife.date product page URL |
| `links.icon` | string\|null | Simple Icons URL |
| `links.releasePolicy` | string\|null | Official release policy URL |
| `releases` | ProductRelease[] | All release cycles |

### ProductRelease (release cycle)

This is the core schema for support status determination.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes | Cycle name (e.g. `"3.12"`, `"22.04"`) |
| `codename` | string\|null | yes | Codename, `null` if none |
| `label` | string | yes | Display label (e.g. `"3.12 'Jammy Jellyfish' (LTS)"`) |
| `releaseDate` | date | yes | Release date (`YYYY-MM-DD`) |
| `isLts` | boolean | yes | Whether this cycle receives long-term support |
| `ltsFrom` | date\|null | yes | LTS phase start date; `null` if not LTS or starts at release |
| `isEoas` | boolean | absent | Whether active support has ended. Absent if product has no active-support phase |
| `eoasFrom` | date\|null | absent | End of active support date |
| `isEol` | boolean | yes | Whether the cycle has reached end-of-life |
| `eolFrom` | date\|null | yes | EOL date; `null` when unknown |
| `isDiscontinued` | boolean | absent | Whether discontinued (mainly hardware) |
| `discontinuedFrom` | date\|null | absent | Discontinuation date |
| `isEoes` | boolean\|null | absent | Whether extended support has ended. `null` if not eligible. Absent if product has no extended-support phase |
| `eoesFrom` | date\|null | absent | End of extended support date |
| `isMaintained` | boolean | yes | Whether this cycle still has any level of support |
| `latest` | ProductVersion\|null | yes | Latest version in this cycle |
| `custom` | object\|null | no | Product-specific custom fields |

### ProductVersion

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Version name (e.g. `"22.04.5"`) |
| `date` | date\|null | Release date; `null` if unknown |
| `link` | string\|null | Changelog or release notes URL |

### ProductReleaseResponse

```json
{
  "schema_version": "1.0.0",
  "generated_at": "2025-01-15T12:00:00+01:00",
  "result": ProductRelease
}
```

### Identifier

| Field | Type | Description |
| --- | --- | --- |
| `id` | string | Identifier value (e.g. `"cpe:/o:canonical:ubuntu_linux"`) |
| `type` | string | Identifier type (e.g. `"cpe"`, `"purl"`, `"repology"`) |

## HTTP status codes

| Code | Meaning | Action |
| --- | --- | --- |
| 200 | OK | Parse the response |
| 301 | Moved Permanently | Follow the redirect (curl `-L` does this) |
| 304 | Not Modified | Use cached version |
| 404 | Not Found | Product or release cycle does not exist; body is HTML, not JSON |
| 429 | Too Many Requests | Rate limited; check `Retry-After` header and wait |

## Example: full product query

```sh
curl -sS "https://endoflife.date/api/v1/products/python" | jq
```

```json
{
  "schema_version": "1.0.0",
  "generated_at": "2025-07-24T10:00:00+00:00",
  "last_modified": "2025-07-20T08:00:00+00:00",
  "result": {
    "name": "python",
    "label": "Python",
    "aliases": [],
    "category": "lang",
    "tags": ["lang", "python-software-foundation"],
    "versionCommand": "python --version",
    "identifiers": [
      { "id": "pkg:generic/python", "type": "purl" }
    ],
    "labels": {
      "eol": "End of life",
      "eoas": null,
      "eoes": null,
      "discontinued": null
    },
    "links": {
      "icon": "https://simpleicons.org/icons/python.svg",
      "html": "https://endoflife.date/python",
      "releasePolicy": "https://devguide.python.org/versions/"
    },
    "releases": [
      {
        "name": "3.13",
        "codename": null,
        "label": "3.13",
        "releaseDate": "2024-10-07",
        "isLts": false,
        "ltsFrom": null,
        "isEol": false,
        "eolFrom": "2029-10-31",
        "isMaintained": true,
        "latest": {
          "name": "3.13.5",
          "date": "2025-06-04",
          "link": "https://www.python.org/downloads/release/python-13135/"
        },
        "custom": null
      },
      {
        "name": "3.12",
        "codename": null,
        "label": "3.12",
        "releaseDate": "2023-10-02",
        "isLts": false,
        "ltsFrom": null,
        "isEol": false,
        "eolFrom": "2028-10-02",
        "isMaintained": true,
        "latest": {
          "name": "3.12.11",
          "date": "2025-06-04",
          "link": "https://www.python.org/downloads/release/python-31211/"
        },
        "custom": null
      }
    ]
  }
}
```
