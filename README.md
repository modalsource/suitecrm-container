# SuiteCRM Container

SuiteCRM 7.15.2 on PHP 8.4 + Apache httpd + MariaDB 11.4.

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

```bash
docker compose -f compose.yml -f compose.it.yml up -d
```

## Build without Compose

```bash
docker build -t suitecrm:7.15.2 .
docker run -d -p 8080:80 --name suitecrm suitecrm:7.15.2
```

## Volumes

Database and SuiteCRM data are persisted (`db_data`, `app_data`). If `app_data` is empty on startup, SuiteCRM is automatically copied from the container.
