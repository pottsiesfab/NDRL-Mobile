FROM php:8.3-cli-alpine
RUN apk add --no-cache ca-certificates curl-dev \
    && docker-php-ext-install pdo_mysql curl
WORKDIR /app
COPY worker.php /app/worker.php
USER 20070:20070
ENTRYPOINT ["php", "/app/worker.php"]
CMD ["check"]
