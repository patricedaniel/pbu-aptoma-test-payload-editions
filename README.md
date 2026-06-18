# pbu-aptoma-test-payload-editions

Test payloads and a small CLI for Aptoma **Print Edition Manager** (edition/page/ad import from an external planning tool).

## Quick start

1. **Configure API key** (once):

```bash
cp config/pem.env.sample config/pem.env
# Edit config/pem.env and set APTOM_PEM_API_KEY
```

2. **Push** a payload (every successful `POST` applies changes in DrEdition):

```bash
./pem-push.sh payloads/edition-shared-pages.json
```

Requires `curl` on macOS (preinstalled). Optional: `jq` for pretty-printed JSON responses.

## `pem-push.sh`

Local shell script that `POST`s a JSON file to PEM. **Create and update are the same call** — resend a payload with the same `editionName` to update.

| Option | Meaning |
|--------|---------|
| `--auto` | Use `/edition` for a JSON object, `/editions` for an array (**default**) |
| `--edition` | Force `POST /edition` |
| `--editions` | Force `POST /editions` (page sharing, bulk) |
| `-c FILE` | Config file (default: `config/pem.env`) |

Exit code `0` on HTTP 2xx; non-zero on errors (including **409** if another import is already running for that edition).

### Examples

```bash
# Bulk import with shared pages (array payload → /editions)
./pem-push.sh payloads/edition-shared-pages.json

# Single edition object
./pem-push.sh payloads/my-edition.json

# Explicit bulk endpoint
./pem-push.sh --editions payloads/edition-shared-pages.json
```

## Repository layout

| Path | Purpose |
|------|---------|
| `pem-push.sh` | CLI to push payloads to PEM |
| `config/pem.env.sample` | Committed template for API key |
| `config/pem.env` | Your local key (**gitignored**) |
| `payloads/` | Working JSON payloads for `./pem-push.sh` |
| `payloads/files/` | Hosted ad PDF/preview assets (referenced by `pdfUrl` / `previewUrl`) |
| `AGENTS.md` | Instructions for AI/code agents |

Copy additional examples from `stuff/Interface to Ad and Page Planning Tool/muster-*.json` into `payloads/` when you need them locally.

### Ad assets (`payloads/files/`)

`edition-shared-pages.json` references one test ad on Leopoldstadt page 4:

- `payloads/files/ad-green.pdf` — solid green A4 PDF
- `payloads/files/ad-green-preview.png` — matching preview image

URLs in the payload are pinned to a GitHub raw commit (`53e5ccc…`) so PEM always fetches the same file revision. **PEM must reach `pdfUrl` and `previewUrl` over HTTPS** — the repo must be public (or URLs otherwise reachable).

Ads with `"ready": true` require both `pdfUrl` and `previewUrl`.

## What PEM does

- **Push (planning → Aptoma):** `POST /edition` (one edition) or `POST /editions` (many editions, required for page sharing)
- **Update:** same `POST` with the same `editionName` — there is no separate PATCH on PEM
- **Response:** `traceId` and `logs` only

More detail: [`stuff/README.md`](stuff/README.md), [`stuff/print-edition-manager-api.md`](stuff/print-edition-manager-api.md).

Official API: [Print Edition Manager API](https://docs.aptoma.com/dredition/api/print-automation-apis/print-edition-manager-api)
