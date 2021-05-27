FROM php:7.4-cli-alpine

RUN set -ex \
  && apk --no-cache add \
    autoconf gcc g++ make libzip-dev git

RUN docker-php-ext-install zip pdo pdo_mysql opcache

WORKDIR /app

ADD ./app /app

RUN chmod -R a+w storage/ bootstrap/cache

CMD ["php", "artisan", "queue:listen"]
