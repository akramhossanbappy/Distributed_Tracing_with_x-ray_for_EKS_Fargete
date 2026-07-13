# syntax=docker/dockerfile:1

# Use PHP 8.4 FPM (Debian)
FROM php:8.4-fpm

# Set environment variables
# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libicu-dev \
    libzip-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    pdo \
    pdo_pgsql \
    bcmath \
    intl \
    zip

# Install Redis extension via PECL
RUN pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /tmp/pear

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions opentelemetry


# Install Composer (latest version)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN mkdir /test
COPY ./test/ /test
#COPY ./php.ini /usr/local/etc/php/php.ini
RUN cd /test && composer install 
# Set working directory to /app_dir
WORKDIR /app_dir
