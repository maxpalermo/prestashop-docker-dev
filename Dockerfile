FROM php:8.2-fpm

ARG WWW_UID=1000
ARG WWW_GID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        zip \
        curl \
        ca-certificates \
        gnupg \
        libicu-dev \
        libzip-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libwebp-dev \
        libonig-dev \
        libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN set -e; \
    if getent group www-data >/dev/null 2>&1; then \
      groupmod -o -g "$WWW_GID" www-data; \
    else \
      groupadd -o -g "$WWW_GID" www-data; \
    fi; \
    if id -u www-data >/dev/null 2>&1; then \
      usermod -o -u "$WWW_UID" -g "$WWW_GID" www-data; \
    else \
      useradd -o -u "$WWW_UID" -g "$WWW_GID" -M -s /usr/sbin/nologin www-data; \
    fi

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        intl \
        pdo_mysql \
        mysqli \
        zip \
        gd \
        opcache

RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Node.js 18 + Yarn (useful for theme tooling)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html
