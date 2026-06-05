FROM docker.io/library/php:8.5.7-cli-alpine3.23

ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/bin/composer

RUN apk --update --no-cache add wget git linux-headers build-base autoconf zeromq-dev zlib-dev \
    && composer global require enlightn/security-checker \
    && install-php-extensions pcntl bcmath sockets xhprof excimer xdebug redis \
    && composer clear-cache

WORKDIR /opt
RUN git clone -b issue-php85 https://github.com/remicollet/php-zmq.git php-zmq \
    && git clone https://github.com/NoiseByNorthwest/php-spx.git

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

ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /app/frontend