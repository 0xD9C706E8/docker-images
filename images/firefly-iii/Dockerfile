# https://github.com/firefly-iii/firefly-iii

# renovate: datasource=github-releases depName=firefly-iii/firefly-iii
ARG FIREFLY_III_VERSION=6.5.6

FROM php:8.5-fpm-alpine@sha256:43591b6592464f5999c14d29948c8616ec61f931ee3982125e5b29cac069ea67

# renovate: datasource=github-releases depName=mlocati/docker-php-extension-installer
ARG INSTALL_PHP_EXTENSIONS_VERSION=2.11.12
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/download/${INSTALL_PHP_EXTENSIONS_VERSION}/install-php-extensions /usr/local/bin/

RUN install-php-extensions bcmath gd intl mbstring memcached pdo_mysql pdo_pgsql sockets xml zip

COPY --from=composer:2@sha256:eba74b4f394c3241aab6e69c2cda9d42cfaf47666770c9e73885870a554afc9b /usr/bin/composer /usr/local/bin/composer

ARG FIREFLY_III_VERSION
ADD https://github.com/firefly-iii/firefly-iii/archive/refs/tags/v${FIREFLY_III_VERSION}.tar.gz /tmp/firefly-iii.tar.gz

RUN tar xzf /tmp/firefly-iii.tar.gz --strip-components=1 -C /var/www/html \
 && rm /tmp/firefly-iii.tar.gz

WORKDIR /var/www/html

RUN composer install --no-dev --no-scripts --no-interaction \
 && composer update twig/twig --no-scripts --no-interaction \
 && composer dump-autoload --optimize \
 && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN mkdir -p storage/framework/cache/data \
 && mkdir -p storage/framework/sessions \
 && mkdir -p storage/framework/views \
 && mkdir -p storage/logs \
 && mkdir -p storage/upload \
 && mkdir -p storage/app/public \
 && chown -R www-data:www-data storage bootstrap/cache

RUN addgroup -g 1000 abc \
 && adduser -u 1000 -G abc -D -H abc \
 && { echo 'listen = 0.0.0.0:9000'; echo 'clear_env = no'; } >> /usr/local/etc/php-fpm.d/zz-docker.conf \
 && sed -i 's/user = www-data/user = abc/' /usr/local/etc/php-fpm.d/www.conf \
 && sed -i 's/group = www-data/group = abc/' /usr/local/etc/php-fpm.d/www.conf \
 && sed -i 's/listen\.owner = www-data/listen.owner = abc/' /usr/local/etc/php-fpm.d/www.conf \
 && sed -i 's/listen\.group = www-data/listen.group = abc/' /usr/local/etc/php-fpm.d/www.conf \
 && chown -R abc:abc /var/www/html

USER abc

ENV APP_ENV=production \
    FIREFLY_III_PATH=/var/www/html \
    PHP_MAX_EXECUTION_TIME=300 \
    PHP_OPCACHE_ENABLE=1

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD pgrep php-fpm

ENTRYPOINT ["php-fpm"]
