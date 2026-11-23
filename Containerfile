FROM docker.io/library/php:8.5.12-cli-alpine3.24

ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/bin/composer

RUN apk --update --no-cache add wget git linux-headers build-base autoconf pcre2-dev zeromq-dev zlib-dev \
    && composer global require enlightn/security-checker \
    && install-php-extensions pcntl bcmath sockets xhprof excimer redis \
    && IPE_DONT_ENABLE=1 install-php-extensions xdebug \
    && composer clear-cache

WORKDIR /opt
RUN git clone -b issue-php85 https://github.com/remicollet/php-zmq.git php-zmq \
    && git clone https://github.com/NoiseByNorthwest/php-spx.git \
    && git clone --depth 1 --branch 0.1.1 https://github.com/shipmonk-rnd/turbocov.git

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

ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /app/frontend
