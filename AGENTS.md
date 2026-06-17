# AGENTS.md

Shared instructions for AI/code agents working in this repository.

## Project purpose

This repository holds **test payloads and integration notes** for Aptoma **Print Edition Manager (PEM)** and related **DrEdition API** workflows.

It is **not** a LayoutPreview asset repo. Use it to:

- Draft and validate JSON for `POST /edition` and `POST /editions`
- Document page sharing (master + regional editions)
- Document placement coordinates, bleed, and back-sync to a planning tool

## Repository layout

```
AGENTS.md                          ← this file
README.md                          ← human quick start (pem-push.sh usage)
pem-push.sh                        ← CLI: POST JSON payloads to PEM
config/
  pem.env.sample                   ← committed API key template
  pem.env                          ← local key (gitignored)
payloads/                          ← working payloads for pem-push.sh
  edition-shared-pages.json        ← bulk sharing example
stuff/
  README.md                        ← documentation index
  print-edition-manager-api.md     ← PEM: endpoints, create/update, responses
  zwei-apis-post-patch.md          ← PEM vs DrEdition API (POST vs PATCH)
  placement-koordinaten-bleed.md   ← Satzspiegel, mm, randabfallend
  page-sharing-mutationen.md       ← Wienweit + Bezirke, bulk sharing
  ruecksync-planung.md             ← Aptoma → planning tool (webhooks, GET)
  Interface to Ad and Page Planning Tool/
    aptoma-json-muster.md          ← inline JSON examples
    request-beispiele-page-planning.md
    muster-*.json                  ← reference copy-paste payloads
```

## Two APIs (do not confuse them)

| API | Base URL | Direction | HTTP for edition structure |
|-----|----------|-----------|----------------------------|
| **Print Edition Manager** | `https://print-edition-manager.aptoma.no` | Planning → Aptoma | **POST only** (`/edition`, `/editions`, `/refresh`) |
| **DrEdition API** | `https://dredition-api.aptoma.no` | Read/update native resources | **GET**, **PATCH**, POST for other actions |

**Seitenplanung / Inserate importieren:** always **PEM `POST`**.  
**Rücksync / Lesen nach Redaktionsänderung:** **DrEdition API GET** and/or **webhooks** (see `stuff/ruecksync-planung.md`).

## PEM import rules (agents must follow)

1. **Declarative sync** — payload describes target state; PEM diffs against DrEdition.
2. **Stable IDs** — reuse `page.id`, `ad.id`, `placeholder.id` from the planning system across imports.
3. **Print page schema** — DrEdition print page content schema needs `sourceId` (string) for page tracking.
4. **Dry run first** — `POST .../edition?dryRun=true`, then `dryRun=false`.
5. **One import per edition** — parallel imports return `409`; queue per edition.
6. **Response** — `traceId` + `logs` only; no structured placement JSON for back-sync.
7. **Units** — `placement.x/y/width/height` in **mm**; origin at **top-left of margin (Satzspiegel)**.

## Required edition fields (PEM)

- `name` — manager/source name (unique; becomes `source` on objects in DrEdition)
- `productName` — must match DrEdition product
- `editionName` — unique; existing edition is **updated**, not duplicated
- `publishDate` — ISO date
- `config.adItemSchemaName`, `config.pdfItemSchemaName`
- `pages[]` — each with stable `id`

## Sharing (bulk only)

- Page sharing between editions: **`POST /editions`** (array of editions in one payload).
- Declare `sharing[]` only on the **owner** (master) pages.
- Child editions still list all page slots; shared slots often have empty `objects`.
- See `stuff/page-sharing-mutationen.md` and `muster-edition-shared-pages.json`.

## Config flags agents should know

| Flag | Default | Effect |
|------|---------|--------|
| `allowPageDelete` | `false` | Pages missing from payload may be deleted |
| `allowTemplateUpdate` | `false` | Template changes from payload applied |
| `allowPageUnlock.enabled` | `false` | Unlock pages with PDF to apply updates |
| `update.ignorePositionChange` (on ad/pdf) | — | Next import does not reset editor-moved position |

## Testing payloads

**Preferred:** use `./pem-push.sh` (reads `config/pem.env`, defaults to dry-run).

```bash
cp config/pem.env.sample config/pem.env   # once; set APTOM_PEM_API_KEY

# Dry-run (default)
./pem-push.sh payloads/edition-shared-pages.json

# Live import
./pem-push.sh --live payloads/edition-shared-pages.json
```

Script behavior:

- `--dry-run` (default) → `?dryRun=true`; `--live` → `?dryRun=false`
- `--auto` (default): JSON object → `POST /edition`, JSON array → `POST /editions`
- Override with `--edition` or `--editions`
- Exit `1` on non-2xx HTTP (note **409** = parallel import for same edition)
- Pretty-prints response with `jq` when installed

Put new working payloads in `payloads/`. Reference examples remain under `stuff/Interface to Ad and Page Planning Tool/muster-*.json`.

**Raw curl** (equivalent):

```bash
curl -X POST "https://print-edition-manager.aptoma.no/edition?dryRun=true" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <API_KEY>" \
  -d @payloads/my-edition.json
```

API key scopes (PEM): `product.*.read`, `product.*.edition.*`

## Aptoma documentation

- [Print Edition Manager API](https://docs.aptoma.com/dredition/api/print-automation-apis/print-edition-manager-api)
- [Sharing (product)](https://docs.aptoma.com/dredition/use/print-automation/sharing.md)
- [Ads](https://docs.aptoma.com/dredition/setup/print-automation/ads)
- [Webhooks](https://docs.aptoma.com/dredition/setup/dredition/webhooks.md)
- [DrEdition API (Swagger)](https://dredition-api.aptoma.no/documentation)

Query Aptoma docs: append `?ask=<question>` to `.md` doc URLs.

## Working agreements

- Use `./pem-push.sh` for PEM imports; do not embed API keys in scripts or payloads.
- Prefer editing JSON in `payloads/` for runnable tests; keep `stuff/*.md` and `muster-*.json` as reference.
- Keep `productName`, schema names, and template titles aligned with the target DrEdition tenant.
- When adding examples, use realistic Wiener Bezirksblatt naming only if the user/context expects it; otherwise use neutral `WB-YYYY-MM-DD` placeholders.
- Do not commit API keys or tenant secrets.
- Do not commit or push unless explicitly asked.

## When the user asks for new examples

Before generating large payloads, confirm if available:

- Product name and item schema names (`adItemSchemaName`, `pdfItemSchemaName`)
- Default page template title
- Edition naming convention (e.g. `26-26 Wienweit`, `26-26 Leopoldstadt`)
- Which pages are shared vs regional
- Whether placeholders or full ads are needed on first import
