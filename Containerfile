FROM docker.io/library/php:8.6.0-cli-alpine3.24

ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/bin/composer

RUN apk --update --no-cache add wget git linux-headers build-base autoconf pcre2-dev zeromq-dev zlib-dev \
    && composer global require enlightn/security-checker \
    && install-php-extensions pcntl bcmath sockets xhprof \
    && composer clear-cache

RUN IPE_DONT_ENABLE=1 install-php-extensions xdebug/xdebug@5e19866c1766e38c527f9f94faa170370dc4209f

WORKDIR /opt
RUN apk add --no-cache lz4-dev zstd-dev \
    && git clone https://github.com/phpredis/phpredis.git \
    && git -C phpredis checkout --detach a17268cf750e552a86ce20d16e18e7fb6b384384 \
    && git -C phpredis submodule update --init --recursive \
    && docker-php-ext-configure /opt/phpredis --enable-redis-lzf --enable-redis-zstd --enable-redis-lz4 --with-liblz4 \
    && docker-php-ext-install -j"$(nproc)" /opt/phpredis \
    && rm -rf /opt/phpredis

RUN git clone -b issue-php85 https://github.com/remicollet/php-zmq.git php-zmq \
    && git clone https://github.com/NoiseByNorthwest/php-spx.git \
    && git -C php-spx checkout --detach ef1155c0daffd99ebc4ef596633b0d7d699f9e12 \
    && git clone https://github.com/wikimedia/php-excimer.git \
    && git -C php-excimer checkout --detach 34183f9487bf95cd5b8dab50af737d19de5179f7 \
    && docker-php-ext-install /opt/php-excimer \
    && rm -rf /opt/php-excimer \
    && git clone https://github.com/shipmonk-rnd/turbocov.git \
    && git -C turbocov checkout --detach 0dbe4a90fa42d12c1a1460ab2c509d3aca36fa87

WORKDIR /opt/php-zmq
RUN phpize \
    && ./configure \
    && make \
    && make install \
    && rm -rf /opt/php-zmq

WORKDIR /opt/php-spx
RUN phpize \
    && ./configure \
    && make \
    && make install \
    && rm -rf /opt/php-spx

WORKDIR /opt/turbocov
RUN phpize \
    && ./configure --enable-turbocov \
    && make \
    && make install \
    && docker-php-ext-enable turbocov \
    && rm -rf /opt/turbocov

RUN install-php-extensions mbstring

ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /app/frontend
