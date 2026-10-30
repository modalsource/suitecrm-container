# SuiteCRM Container

SuiteCRM 7.15.2 on PHP 8.4 + Apache httpd (Docker image) — plus MariaDB 11.4, added on
top by `compose.yml`.

**Docker image** (`Dockerfile`): PHP 8.4-FPM (Alpine) + Apache httpd (reverse-proxied to
PHP-FPM via `proxy_fcgi`), all PHP extensions required by SuiteCRM, and the SuiteCRM
7.15.2 archive baked in (extracted into `/var/www/html` on first container start by
`docker-entrypoint.sh`). It does **not** include a database — MariaDB is not part of
this image.

**Versioning** (Bitnami-style): Git tag `vX.Y.Z-rN` → Docker tags `X.Y.Z-rN`, `X.Y.Z`, `X.Y`, `X` (senza `latest`). Esempio: `v7.15.2-r0` → `7.15.2-r0`, `7.15.2`, `7.15`, `7`; `v7.15.2-r1` aggiorna gli alias flottanti alla revisione `r1`; `v7.15.3-r0` resetta `r` a `0`. `SUITECRM_VERSION` (i primi 3 numeri) è passato come `build-arg` in CI (`Dockerfile:4`).

**`compose.yml`**: orchestrates the full stack — the `app` service (built from this
image) plus a separate `db` service (`mariadb:11.4`), the network between them, the
persistent volumes (`db_data`, `app_data`), port mapping (`8080:8080`), and the
environment variables that configure the `app` container (DB credentials, silent
install options, etc. — see below).

## Quick Start

```bash
docker compose up -d
```

Open `http://localhost:8080` and follow the installer.

Preconfigured database credentials in `compose.yml`:
- Host: `db`
- Database: `suitecrm`
- User: `suitecrm`
- Password: `suitecrm_password`

## Silent Install

By default the container extracts SuiteCRM and lets you complete setup through the
web installer at `http://localhost:8080/install.php`.

You can skip the web installer entirely by enabling the silent install mode, which
uses SuiteCRM's built-in silent installer (`config_si.php`) to configure the database
and admin account automatically on first boot.

Set `SUITECRM_SILENT_INSTALL=true` (in `compose.yml` or via `docker run -e`) together
with the following variables.

> All `SUITECRM_INSTALL_*` variables are **only read once**, the first time the
> container starts against an empty `app_data` volume (i.e. no `config.php` yet) with
> `SUITECRM_SILENT_INSTALL=true`. They are ignored on every subsequent start, including
> restarts of an already-installed instance — changing them afterwards has no effect
> unless you wipe the `app_data` volume.

| Variable | Default | Description |
|---|---|---|
| `SUITECRM_SILENT_INSTALL` | `false` | Set to `true` to enable silent install (this is the only variable read on every start, since it's the switch itself) |
| `SUITECRM_INSTALL_DB_HOST` | `db` | Database host |
| `SUITECRM_INSTALL_DB_PORT` | `3306` | Database port |
| `SUITECRM_INSTALL_DB_NAME` | `suitecrm` | Database name (must already exist) |
| `SUITECRM_INSTALL_DB_USER` | `suitecrm` | Database user (must already exist with access to the DB) |
| `SUITECRM_INSTALL_DB_PASSWORD` | *(empty)* | Database password |
| `SUITECRM_INSTALL_SITE_URL` | `http://localhost:8080` | Public URL of the instance |
| `SUITECRM_INSTALL_SYSTEM_NAME` | `SuiteCRM` | Display name shown in the UI |
| `SUITECRM_INSTALL_ADMIN_PASSWORD` | `admin` | Password for the `admin` user (username is always `admin`) |
| `SUITECRM_INSTALL_DEMO_DATA` | `no` | Set to `yes` to populate demo data |

### Locale & currency

Also silent-install-only (see note above).

| Variable | Default | Description |
|---|---|---|
| `SUITECRM_INSTALL_DEFAULT_LANGUAGE` | `en_us` | Default language pack code (e.g. `it_it`, `de_de`) assigned to new users/the system default |
| `SUITECRM_INSTALL_DEFAULT_CHARSET` | `UTF-8` | Default charset |
| `SUITECRM_INSTALL_DEFAULT_DATE_FORMAT` | `m/d/Y` | Default date format (`m/d/Y`, `d/m/Y`, `Y-m-d`, etc.) — `install/install_utils.php:1682`, `performSetup.php:629` |
| `SUITECRM_INSTALL_DEFAULT_TIME_FORMAT` | `h:ia` | Default time format (`h:ia`, `H:i`, `H:i:s`, etc.) — `install/install_utils.php:1682`, `performSetup.php:632` |
| `SUITECRM_INSTALL_CURRENCY_NAME` | `US Dollar` | Default currency name |
| `SUITECRM_INSTALL_CURRENCY_SYMBOL` | `$` | Default currency symbol |
| `SUITECRM_INSTALL_CURRENCY_ISO4217` | `USD` | Default currency ISO 4217 code |
| `SUITECRM_INSTALL_CURRENCY_SIGNIFICANT_DIGITS` | `2` | Decimal digits for the default currency |
| `SUITECRM_INSTALL_NUMBER_GROUPING_SEPARATOR` | `,` | Thousands separator |
| `SUITECRM_INSTALL_DECIMAL_SEPARATOR` | `.` | Decimal separator |
| `SUITECRM_INSTALL_DISABLE_PERSISTENT_CONNECTIONS` | `false` | Disable persistent DB connections |

Note: `SUITECRM_INSTALL_DEFAULT_LANGUAGE` only sets the system/user default language in
`config.php`; the login page shown to an anonymous visitor is still driven by the
browser's locale / the language dropdown, not by this setting.

An example `compose.it.yml` override with all Italian locale values is provided — see
[Italian locale example](#italian-locale-example) below.

### Not supported: Full-Text Search / Elasticsearch

SuiteCRM 7.15.x's installer **always** writes a disabled `search.ElasticSearch` block
into `config.php` with hardcoded defaults (`install/suite_install/Search.php`), and the
legacy `setup_fts_*` keys once accepted by `config_si.php` are dead code in this version
(`getFTSEngineType()` in `include/utils.php` has no remaining callers). Setting them via
`config_si.php` has no effect. Elasticsearch must be configured after installation, either
through **Admin > Search > Elasticsearch** in the UI, or by editing `config.php`'s
`search.ElasticSearch` array directly.

Notes:
- The database and DB user must already exist (e.g. provisioned by the `db` service's
  `MYSQL_DATABASE`/`MYSQL_USER` env vars) — the installer will not try to create them.
- Silent install only runs once, when `config.php` does not exist yet (e.g. on a fresh
  `app_data` volume). It has no effect on an already-installed instance.
- **Change `SUITECRM_INSTALL_ADMIN_PASSWORD` for anything beyond local testing** — the
  default value is intentionally weak.

## Italian locale example

`compose.it.yml` is a Compose override that sets all the Italian locale/currency values
(`it_it`, Euro, `.`/`,` separators) on top of the base `compose.yml`, and enables silent
install. Run it with:

The image bundles the official `it_IT` language pack (SuiteCRM community
translations, 7.15 line). `docker-entrypoint.sh` registers the language with the
installer via `install/lang.config.php` for silent installs and then installs
the pack through `ModuleInstall/PackageManager` (as `Admin > Module Loader` would),
so it is tracked in `upgrade_history` and visible in `Admin > Module Loader` /
`Admin > Upgrade History`. No manual Module Loader step is needed when
`SUITECRM_INSTALL_DEFAULT_LANGUAGE=it_it`.

```bash
docker compose -f compose.yml -f compose.it.yml up -d
```

## Build without Compose

```bash
# Build locale: SUITECRM_VERSION è estratto dal tag vX.Y.Z-rN in CI; in locale passalo esplicitamente
docker build --build-arg SUITECRM_VERSION=7.15.2 -t suitecrm:7.15.2-r0 .
docker run -d -p 8080:8080 --name suitecrm suitecrm:7.15.2-r0
# Tag GHCR pubblicati da CI (senza latest): 7.15.2-r0, 7.15.2, 7.15, 7
```

## Running as non-root

The image runs as Alpine's `www-data` (UID/GID **82**) by default (`USER 82:82`)
and Apache listens on **8080** instead of 80: unprivileged processes cannot bind
ports below 1024 in Kubernetes (Docker may allow it, but 8080 works everywhere).

- **Compose**: `user: "82:82"` is already set for both `app` and `cron`; the host
  port stays 8080.
- **Kubernetes**: the manifests set `runAsNonRoot`, `runAsUser`/`runAsGroup: 82`
  and `fsGroup: 82`. The latter is required because a freshly provisioned PVC is
  root-owned: `fsGroup` makes it writable without running the container as root.
  The Service still exposes port 80 and forwards to `targetPort: 8080`, so
  Ingress and clients are unchanged.
- **Existing volumes**: Docker named volumes created by older revisions were
  already chowned to `www-data` by the entrypoint. For bind mounts or volumes
  with different ownership, fix them once:
  ```bash
  docker run --rm -u 0 -v suitecrm_app_data:/var/www/html \
    alpine chown -R 82:82 /var/www/html
  ```
- The entrypoint is still usable when explicitly started as root (e.g.
  `--user 0` for repairs): privileged operations are guarded and skipped when
  running unprivileged.

## Volumes

Database and SuiteCRM data are persisted (`db_data`, `app_data`). If `app_data` is empty on startup, SuiteCRM is automatically copied from the container.

## Kubernetes

Generic deployment manifests live under `k8s/`:

- `k8s/` - plain YAML + Helm values (Percona `ps-db`), single generic instance with
  placeholder values. See `k8s/README.md` for the runbook.
- `k8s/kustomize/` - Kustomize examples with in-cluster MariaDB and NGINX/Traefik
  overlays, for standalone users.

## Security scanning (CI)

All workflows live in `.github/workflows/` and run [Trivy](https://github.com/aquasecurity/trivy)
with `severity: CRITICAL,HIGH` + `ignore-unfixed: true` (only findings with a fix available):

| Workflow | Trigger | What it does |
|---|---|---|
| `docker-pr.yml` | pull request on `main` | builds the image, squashes layers, scans and **fails the PR** on findings |
| `docker-publish.yml` | tag `vX.Y.Z-rN` (or `workflow_dispatch` on a tag) | builds/pushes to GHCR, scans and fails on findings |
| `trivy-weekly.yml` | `schedule` (Mondays 06:00 UTC) + manual | re-scans the **published** image |
| `auto-rebuild.yml` | `schedule` (Mondays 08:00 UTC) + manual | detects fixable vulns and publishes a bumped revision |

The weekly job is a safety net: the published image is immutable, but the Trivy
vulnerability DB keeps moving, so it catches CVEs disclosed after a release. It
scans the floating major tag (`ghcr.io/<repo>:7` by default, overridable via
`workflow_dispatch`), uploads the SARIF report to the **Security** tab, and
opens/updates a single issue (label `security`) instead of failing the run — the
issue is closed automatically once a scan comes back clean.

Only `CRITICAL,HIGH` findings gate the issue. Fixable `MEDIUM`/`LOW` findings are
listed in an **informational** section of the issue and never affect the gate.

`auto-rebuild.yml` closes the loop: when the published image has fixable
`CRITICAL,HIGH` findings it bumps the revision (`vX.Y.Z-rN` → `vX.Y.Z-r(N+1)`),
pushes the tag and publishes it (reusing `docker-publish.yml` via
`workflow_dispatch`), then re-runs the weekly scan. A `workflow_dispatch` with
`dry_run: true` (the default when launched manually) only reports the revision
that would be created.
