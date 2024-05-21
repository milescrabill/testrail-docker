FROM php:8.1-fpm-bullseye
# Change this as needed to match container
ARG ARG_PHP_VERSION=8.1
ENV TR_DEFAULT_TASK_EXECUTION=90
ENV TR_CONFIGPATH="/var/www/testrail/config/"
ENV TR_DEFAULT_LOG_DIR="/opt/testrail/logs/"
ENV TR_DEFAULT_AUDIT_DIR="/opt/testrail/audit/"
ENV TR_DEFAULT_REPORT_DIR="/opt/testrail/reports/"
ENV TR_DEFAULT_ATTACHMENT_DIR="/opt/testrail/attachments/"
ENV OPENSSL_CONF=/etc/ssl/

RUN apt-get update                                  \
      && apt-get -y install --no-install-recommends \
        fontconfig                                  \
        iputils-ping                                \
        libfreetype6-dev                            \
        libjpeg-dev                                 \
        libldap2-dev                                \
        libpng-dev                                  \
        libuv1                                      \
        libzip-dev                                  \
        mariadb-client                              \
        telnet                                      \
        unzip                                       \
        vim                                         \
        wget                                        \
        zip                                         \
      && apt-get clean                              \
      && rm -rf /var/lib/apt/lists/*

# # The built-in docker-php-ext-install tool doesn't install the imagick extension,
# # and we have to resort to a different tool.
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN install-php-extensions gd                   \
      && install-php-extensions imagick         \
      && install-php-extensions ioncube_loader  \
      && install-php-extensions mysqli          \
      && install-php-extensions pdo_mysql       \
      && install-php-extensions zip

RUN mkdir -p /var/www/testrail                 \
      &&  mkdir -p /opt/testrail/attachments   \
                   /opt/testrail/reports       \
                   /opt/testrail/logs          \
                   /opt/testrail/audit

COPY php.ini /usr/local/etc/php/conf.d/php.ini

RUN wget -O /tmp/multiarch-support.deb                                                      \
      https://testrail-mirror.s3.amazonaws.com/multiarch-support_2.27-3ubuntu1.6_amd64.deb  \
      && dpkg -i /tmp/multiarch-support.deb                                                 \
      && rm -fv /tmp/multiarch-support.deb

RUN wget -O /tmp/cassandra-cpp-driver.deb                                                 \
      https://testrail-mirror.s3.amazonaws.com/cassandra-cpp-driver_2.16.0-1_amd64.deb    \
      && dpkg -i /tmp/cassandra-cpp-driver.deb                                            \
      && rm -fv /tmp/cassandra-cpp-driver.deb

RUN wget -O /tmp/cassandra.so                                                       \
      https://testrail-mirror.s3.amazonaws.com/php/${ARG_PHP_VERSION}/cassandra.so  \
      && mv /tmp/cassandra.so $(php -i | grep ^extension_dir | cut -d ' ' -f 3)     \
      && echo extension=cassandra.so > /usr/local/etc/php/conf.d/cassandra.ini

RUN addgroup --gid 10001 app                                                \
      && adduser --gid 10001 --uid 10001 --home /app --shell /sbin/nologin  \
         --disabled-password --gecos we,dont,care,yeah app

RUN rm -rf /usr/local/etc/php-fpm*

RUN echo '{"name":"${REPO_NAME}","version":"${GIT_TAG}","source":"${REPO_URL}","commit":"${GIT_COMMIT}"}' > version.json
COPY version.json /app/

COPY entrypoint.sh /
RUN chmod 0755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

WORKDIR /var/www/testrail
EXPOSE 9000
VOLUME /var/www/testrail
USER app
