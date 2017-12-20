FROM debian:stretch-slim

# Install essential packages
RUN apt-get update && \
    apt-get install -q -y --no-install-recommends apt-transport-https curl wget tar \
        pwgen whois lnav sudo cron zip unzip git lsb-release ca-certificates gnupg dirmngr

# Create azuracast user.
RUN adduser --home /var/azuracast --disabled-password --gecos "" azuracast \
    && chown -R azuracast:azuracast /var/azuracast \
    && echo 'azuracast ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && mkdir -p /var/azuracast/www_tmp \
    && chmod -R 777 /var/azuracast/www_tmp

# Install PHP 7.2
RUN LC_ALL=C.UTF-8 \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get install -q -y --no-install-recommends php7.2-fpm php7.2-cli php7.2-gd \
     php7.2-curl php7.2-xml php7.2-zip php7.2-mysqlnd php7.2-mbstring php7.2-intl php7.2-redis

RUN mkdir -p /run/php
RUN touch /run/php/php7.2-fpm.pid

COPY ./php.ini /etc/php/7.2/fpm/conf.d/05-azuracast.ini
COPY ./php.ini /etc/php/7.2/cli/conf.d/05-azuracast.ini
COPY ./phpfpmpool.conf /etc/php/7.2/fpm/pool.d/www.conf

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Set up locales
COPY locale.gen /etc/locale.gen

RUN apt-get update \
    && ln -s /etc/locale.alias /usr/share/locale/locale.alias \
    && apt-get install -q -y locales gettext

# Set up crontab tasks
ADD crontab /etc/cron.d/azuracast-cron

RUN chmod 0644 /etc/cron.d/azuracast-cron \
    && touch /var/log/cron.log \
    && touch /var/azuracast/.docker

# Install PIP and Ansible
RUN echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" | sudo tee /etc/apt/sources.list.d/ansible.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 \
    && apt-get update \
    && apt-get install -q -y --no-install-recommends python2.7 python-pip python-setuptools \
      python-wheel python-mysqldb ansible && \
    pip install --upgrade pip && \
    pip install influxdb

# AzuraCast installer and update commands
COPY scripts/ /usr/bin
RUN chmod a+x /usr/bin/azuracast_* && \
    chmod a+x /usr/bin/locale_*

CMD ["/usr/sbin/php-fpm7.2", "-F", "--fpm-config", "/etc/php/7.2/fpm/php-fpm.conf", "-c", "/etc/php/7.2/fpm/"]