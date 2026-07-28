# Stage 1: Download e preparazione SuiteCRM
FROM alpine:3.20 AS builder

ARG SUITECRM_VERSION=7.15.1

RUN apk add --no-cache curl unzip

WORKDIR /tmp
RUN curl -fsSL -o suitecrm.zip \
    "https://github.com/SuiteCRM/SuiteCRM/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip" \
    && unzip suitecrm.zip \
    && mv "SuiteCRM-${SUITECRM_VERSION}" /suitecrm

# Stage 2: PHP 8.4 + Apache httpd
FROM php:8.4-apache

# Dipendenze di sistema ed estensioni PHP richieste da SuiteCRM
RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libldap2-dev \
        libzip-dev \
        libonig-dev \
        libicu-dev \
        libxml2-dev \
        unzip \
        cron \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        mysqli \
        pdo_mysql \
        gd \
        mbstring \
        zip \
        bcmath \
        calendar

RUN docker-php-ext-install -j$(nproc) \
        intl \
        ldap \
        soap

# Abilita mod_rewrite di Apache
RUN a2enmod rewrite

# Configura Apache per permettere .htaccess
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' \
        /etc/apache2/apache2.conf || true

# Copia SuiteCRM dal builder in una directory sorgente (non la web root)
COPY --from=builder /suitecrm /usr/src/suitecrm

# Permessi sulla sorgente
RUN chown -R www-data:www-data /usr/src/suitecrm \
    && find /usr/src/suitecrm -type d -exec chmod 755 {} \; \
    && find /usr/src/suitecrm -type f -exec chmod 644 {} \; \
    && chmod -R 775 /usr/src/suitecrm/cache \
    && chmod -R 775 /usr/src/suitecrm/upload \
    && chmod -R 775 /usr/src/suitecrm/config.php \
    || true

# Cron per SuiteCRM scheduler
RUN echo "* * * * * www-data php -f /var/www/html/cron.php > /dev/null 2>&1" \
    > /etc/cron.d/suitecrm \
    && chmod 0644 /etc/cron.d/suitecrm

# Configurazione PHP per SuiteCRM
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

WORKDIR /var/www/html

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 80

CMD ["apache2-foreground"]