# SuiteCRM Container

SuiteCRM 7.15.1 on PHP 8.4 + Apache httpd + MariaDB 11.4.

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

## Build without Compose

```bash
docker build -t suitecrm:7.15.1 .
docker run -d -p 8080:80 --name suitecrm suitecrm:7.15.1
```

## Volumes

Database and SuiteCRM data are persisted (`db_data`, `app_data`). If `app_data` is empty on startup, SuiteCRM is automatically copied from the container.
