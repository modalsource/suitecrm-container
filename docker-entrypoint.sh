#!/bin/sh
set -e

# Start PHP-FPM in background (Alpine uses FPM + Apache proxy_fcgi)
php-fpm -D

if [ -z "$(ls -A /var/www/html 2>/dev/null)" ]; then
    echo "Copying SuiteCRM to /var/www/html..."
    cp -rp /usr/src/suitecrm/* /var/www/html/
    echo "SuiteCRM copied."
fi

if [ ! -f /var/www/html/custom/private.key ] || [ ! -f /var/www/html/custom/public.key ]; then
    echo "Generating RSA keys in /var/www/html/custom/..."
    mkdir -p /var/www/html/custom
    openssl genrsa -out /var/www/html/custom/private.key 2048
    openssl rsa -in /var/www/html/custom/private.key -pubout -out /var/www/html/custom/public.key
    chmod 640 /var/www/html/custom/private.key
    chgrp www-data /var/www/html/custom/private.key /var/www/html/custom/public.key
    echo "Keys generated."
fi

echo "Copying RSA keys to /var/www/html/Api/V8/OAuth2/..."
cp -rp /var/www/html/custom/private.key /var/www/html/Api/V8/OAuth2/
cp -rp /var/www/html/custom/public.key /var/www/html/Api/V8/OAuth2/
echo "Keys copied."

echo "Applying permissions on /var/www/html..."
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -print0 | xargs -0 chmod 755
find /var/www/html -type f -print0 | xargs -0 chmod 644
chmod -R 775 /var/www/html/cache /var/www/html/upload 2>/dev/null || true
chmod 775 /var/www/html/config.php 2>/dev/null || true
echo "Permissions applied."

exec "$@"