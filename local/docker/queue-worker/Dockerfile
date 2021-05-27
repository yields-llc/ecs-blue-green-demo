FROM php:7.4-cli-alpine

RUN set -ex \
  && apk --no-cache add \
    autoconf gcc g++ make libzip-dev git

RUN docker-php-ext-install zip pdo pdo_mysql opcache

CMD ["php", "artisan", "queue:listen"]
