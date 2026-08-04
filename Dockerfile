# Stage 1: Download SuiteCRM zip
FROM alpine:3.24 AS builder

ARG SUITECRM_VERSION=7.15.1

RUN apk add --no-cache curl

RUN curl -fsSL -o /suitecrm.zip \
    "https://github.com/SuiteCRM/SuiteCRM/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip"

# Stage 2: PHP 8.4 Alpine + Apache httpd + PHP-FPM
FROM php:8.5-fpm-alpine

ARG SUITECRM_VERSION

# Runtime system dependencies (Alpine)
# unzip serve all'estrazione in docker-entrypoint.sh
RUN apk update && apk upgrade --no-cache \
    && apk add --no-cache \
        apache2 \
        apache2-proxy \
        apache2-utils \
        curl \
        unzip \
        freetype \
        libjpeg-turbo \
        libpng \
        libldap \
        openldap \
        libzip \
        oniguruma \
        icu-libs \
        libxml2 \
        ca-certificates \
    && rm -rf /var/cache/apk/*

# Build PHP extensions, then nuke build-deps in the same layer
RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        openldap-dev \
        libzip-dev \
        oniguruma-dev \
        icu-dev \
        libxml2-dev \
    ; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j$(nproc) \
        mysqli \
        pdo_mysql \
        gd \
        mbstring \
        zip \
        bcmath \
        calendar \
        intl \
        ldap \
        soap \
    ; \
    apk del .build-deps; \
    rm -rf /var/cache/apk/* /tmp/*

# Enable Apache modules and configure for PHP-FPM + SuiteCRM
RUN set -eux; \
    sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' /etc/apache2/httpd.conf; \
    sed -i 's/#LoadModule proxy_module/LoadModule proxy_module/' /etc/apache2/httpd.conf; \
    sed -i 's/#LoadModule proxy_fcgi_module/LoadModule proxy_fcgi_module/' /etc/apache2/httpd.conf; \
    sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/' /etc/apache2/httpd.conf; \
    sed -i 's/^User apache/User www-data/' /etc/apache2/httpd.conf; \
    sed -i 's/^Group apache/Group www-data/' /etc/apache2/httpd.conf; \
    sed -i 's/^#ServerName www.example.com:80/ServerName localhost:80/' /etc/apache2/httpd.conf; \
    sed -i 's|/var/www/localhost/htdocs|/var/www/html|g' /etc/apache2/httpd.conf

# PHP-FPM pool config (use same uid/gid as Apache)
RUN set -eux; \
    { \
        echo '[www]'; \
        echo 'user = www-data'; \
        echo 'group = www-data'; \
        echo 'listen = 127.0.0.1:9000'; \
        echo 'pm = dynamic'; \
        echo 'pm.max_children = 10'; \
        echo 'pm.start_servers = 2'; \
        echo 'pm.min_spare_servers = 1'; \
        echo 'pm.max_spare_servers = 5'; \
    } > /usr/local/etc/php-fpm.d/zzz-suitecrm.conf

# Apache: PHP-FPM handler via proxy_fcgi
RUN set -eux; \
    { \
        echo '<FilesMatch \.php$>'; \
        echo '    SetHandler "proxy:fcgi://127.0.0.1:9000"'; \
        echo '</FilesMatch>'; \
    } > /etc/apache2/conf.d/php-fpm.conf

# Apache: allow .htaccess overrides in SuiteCRM
RUN set -eux; \
    { \
        echo '<Directory /var/www/html>'; \
        echo '    AllowOverride All'; \
        echo '</Directory>'; \
    } > /etc/apache2/conf.d/suitecrm-dir.conf

# Copy SuiteCRM zip (estratto all'avvio da docker-entrypoint.sh)
COPY --from=builder /suitecrm.zip /usr/src/suitecrm.zip

# PHP configuration overrides for SuiteCRM
RUN { \
        echo "upload_max_filesize = 100M"; \
        echo "post_max_size = 100M"; \
        echo "max_execution_time = 600"; \
        echo "max_input_vars = 3000"; \
        echo "memory_limit = 256M"; \
        echo "error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_NOTICE"; \
        echo "display_errors = Off"; \
        echo "log_errors = On"; \
    } > /usr/local/etc/php/conf.d/suitecrm.ini

# Remove PEAR, dev headers, build scripts (not needed at runtime)
RUN rm -rf \
        /usr/local/include/php \
        /usr/local/lib/php/PEAR \
        /usr/local/lib/php/build \
        /usr/local/lib/php/test \
        /usr/local/lib/php/doc \
        /usr/local/lib/php/Archive \
        /usr/local/lib/php/Console \
        /usr/local/lib/php/OS \
        /usr/local/lib/php/Structures \
        /usr/local/lib/php/XML \
        /usr/local/lib/php/data \
        /usr/local/lib/php/PEAR.php \
        /usr/local/lib/php/System.php \
        /usr/local/lib/php/pearcmd.php \
        /usr/local/lib/php/peclcmd.php \
        /usr/local/bin/pear \
        /usr/local/bin/peardev \
        /usr/local/bin/pecl \
        /usr/local/bin/phpize \
        /usr/local/bin/php-config \
        /usr/local/etc/pear.conf

WORKDIR /var/www/html

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 80

CMD ["httpd", "-D", "FOREGROUND"]
