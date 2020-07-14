FROM alpine:3.12.0 as base

RUN apk add --update --no-cache \
    bash \
    coreutils \
    curl \
    make \
    nginx \
    php7-fpm \
    php7-apcu \
    php7-ctype \
    php7-curl \
    php7-dom \
    php7-gd \
    php7-iconv \
    php7-imagick \
    php7-json \
    php7-intl \
    php7-mcrypt \
    php7-fileinfo \
    php7-mbstring \
    php7-opcache \
    php7-openssl \
    php7-pdo \
    php7-pdo_mysql \
    php7-pdo_pgsql \
    php7-pdo_sqlite \
    php7-posix \
    php7-mysqli \
    php7-xml \
    php7-phar \
    php7-tokenizer \
    php7-session \
    php7-simplexml \
    php7-zip \
    php7-xmlwriter \
    supervisor

RUN rm /etc/nginx/conf.d/default.conf
COPY .docker/nginx.conf /etc/nginx/

RUN echo "upstream php-upstream { server 127.0.0.1:9001; }" > /etc/nginx/conf.d/upstream.conf

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -sf /dev/stderr /var/log/php7/error.log

COPY .docker/symfony.prod.ini  /etc/php7/conf.d/
COPY .docker/symfony.prod.ini  /etc/php7/cli/conf.d/

RUN rm /etc/php7/php-fpm.d/www.conf
COPY .docker/php-fpm.conf /etc/php7/php-fpm.d/

COPY .docker/supervisord.conf /etc/

WORKDIR /symfony

# ----

FROM base as composer

RUN echo "$(curl -sS https://composer.github.io/installer.sig) -" > composer-setup.php.sig \
    && curl -sS https://getcomposer.org/installer | tee composer-setup.php | sha384sum -c composer-setup.php.sig \
    && php composer-setup.php && rm composer-setup.php* \
    && chmod +x composer.phar && mv composer.phar /usr/bin/composer

COPY composer.json .
COPY composer.lock .

COPY symfony.lock .
COPY .env* ./

RUN composer install --no-ansi --no-dev --no-interaction --no-plugins --no-progress --no-scripts --no-suggest --optimize-autoloader
RUN composer dump-env prod

# ----

FROM base as assets

RUN mkdir -p public/build

COPY composer.json package.json* ./
COPY composer.json yarn.lock* ./

COPY composer.json webpack.config.js* ./
COPY composer.json assets* ./assets/

RUN if [ -f webpack.config.js ]; then \
      apk add --update --no-cache yarn; \
      yarn; \
      yarn encore production; \
    fi

# ----

FROM base

COPY . .

COPY --from=composer /symfony/vendor vendor
COPY --from=composer /symfony/.env.local.php .

COPY --from=assets /symfony/public/build public/build

COPY .docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN addgroup symfony && adduser -D -G symfony symfony && \
    chown -R symfony:symfony /symfony /var/lib/nginx /etc/nginx

USER symfony

EXPOSE 9000
ENTRYPOINT ["/entrypoint.sh"]