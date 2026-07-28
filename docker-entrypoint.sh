#!/bin/bash
set -e

if [ -z "$(ls -A /var/www/html 2>/dev/null)" ]; then
    echo "Copio SuiteCRM in /var/www/html..."
    cp -rp /usr/src/suitecrm/* /var/www/html/
    echo "SuiteCRM copiato."
fi

if [ ! -f /var/www/html/custom/private.key ] || [ ! -f /var/www/html/custom/public.key ]; then
    echo "Genero chiavi RSA in /var/www/html/custom/..."
    mkdir -p /var/www/html/custom
    openssl genrsa -out /var/www/html/custom/private.key 2048
    openssl rsa -in /var/www/html/custom/private.key -pubout -out /var/www/html/custom/public.key
    chmod 640 /var/www/html/custom/private.key
    chgrp www-data /var/www/html/custom/private.key /var/www/html/custom/public.key
    echo "Chiavi generate."
fi

echo "Copio le chiavi RSA in /var/www/html/Api/V8/OAuth2/..."
cp -rp /var/www/html/custom/private.key /var/www/html/Api/V8/OAuth2/
cp -rp /var/www/html/custom/public.key /var/www/html/Api/V8/OAuth2/
echo "Chiavi copiate."

echo "Applico permessi su /var/www/html..."
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -print0 | xargs -0 chmod 755
find /var/www/html -type f -print0 | xargs -0 chmod 644
chmod -R 775 /var/www/html/cache /var/www/html/upload 2>/dev/null || true
chmod 775 /var/www/html/config.php 2>/dev/null || true
echo "Permessi applicati."

exec "$@"