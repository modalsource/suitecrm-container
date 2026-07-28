# SuiteCRM Container

SuiteCRM 7.15.1 su PHP 8.4 + Apache httpd + MariaDB 11.4.

## Avvio

```bash
docker compose up -d
```

Apri `http://localhost:8080` e segui l'installer.

Dati database preconfigurati in `compose.yml`:
- Host: `db`
- Database: `suitecrm`
- User: `suitecrm`
- Password: `suitecrm_password`

## Build senza compose

```bash
docker build -t suitecrm:7.15.1 .
docker run -d -p 8080:80 --name suitecrm suitecrm:7.15.1
```

## Volumi

I dati del database e di SuiteCRM sono persistenti (`db_data`, `app_data`). Se `app_data` è vuoto all'avvio, SuiteCRM viene copiato automaticamente dal container.