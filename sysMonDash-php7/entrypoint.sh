#!/bin/bash

XDEBUG_REMOTE_HOST=${XDEBUG_REMOTE_HOST:-"172.17.0.1"}
XDEBUG_IDE_KEY=${XDEBUG_IDE_KEY:-"ide"}

setup_app () {
    [[ ! -d "./sysMonDash" ]] && mkdir sysMonDash

    if [ ! -e "./sysMonDash/index.php" ]; then
        echo -e "\nUnpacking sysMonDash ..."

        unzip "${SMD_BRANCH}.zip" \
            && mv "sysMonDash-${SMD_BRANCH}"/* sysMonDash \
            && rmdir "sysMonDash-${SMD_BRANCH}" \
            && chown ${APACHE_RUN_USER}:${SMD_UID} -R sysMonDash/ \
            && chmod g+w -R sysMonDash/
    fi

    mkdir /etc/sysMonDash \
        && chown www-data:www-data /etc/sysMonDash
}

setup_composer () {
    echo -e "\nSetting up composer ..."

    pushd ./sysMonDash

    if [ ! -e "./sysMonDash/composer.phar" ]; then
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
        php composer-setup.php
        php -r "unlink('composer-setup.php');"
    fi

    php composer.phar self-update && php composer.phar install

    popd
}

setup_locales() {
  if [ ! -e ".setup" ]; then
    LOCALE_GEN="/etc/locale.gen"

    echo -e "\nSetting up locales ..."

    echo -e "\n### sysMonDash locales" >> $LOCALE_GEN
    echo "es_ES.UTF-8 UTF-8" >> $LOCALE_GEN
    echo "en_US.UTF-8 UTF-8" >> $LOCALE_GEN
    echo "de_DE.UTF-8 UTF-8" >> $LOCALE_GEN
    echo "ca_ES.UTF-8 UTF-8" >> $LOCALE_GEN
    echo "fr_FR.UTF-8 UTF-8" >> $LOCALE_GEN
    echo "ru_RU.UTF-8 UTF-8" >> $LOCALE_GEN
    echo "po_PO.UTF-8 UTF-8" >> $LOCALE_GEN
    echo "nl_NL.UTF-8 UTF-8" >> $LOCALE_GEN

    echo 'LANG="en_US.UTF-8"' > /etc/default/locale

    dpkg-reconfigure --frontend=noninteractive locales
    update-locale LANG=en_US.UTF-8

    LANG=en_US.UTF-8

    echo "1" > .setup
 fi
}

setup_apache () {
    echo -e "Setting up xdebug variables ...\n"
    sed -i 's/__XDEBUG_REMOTE_HOST__/'"$XDEBUG_REMOTE_HOST"'/' /etc/php/7.0/apache2/conf.d/20-xdebug.ini
    sed -i 's/__XDEBUG_IDE_KEY__/'"$XDEBUG_IDE_KEY"'/' /etc/php/7.0/apache2/conf.d/20-xdebug.ini
}

echo "Starting with UID : ${SMD_UID}"
id ${SMD_UID} > /dev/null 2>&1 || useradd --shell /bin/bash -u ${SMD_UID} -o -c "" -m user
export HOME=/home/user

setup_locales
setup_apache
setup_app
#setup_composer

if [ "$1" == "apache" ]; then
    # Apache gets grumpy about PID files pre-existing
    rm -f ${APACHE_PID_FILE}

    exec /usr/sbin/apache2ctl -DFOREGROUND
fi

echo -e "Starting $@ ...\n"
exec gosu ${SMD_UID} "$@"
