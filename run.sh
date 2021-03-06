#!/bin/sh
set -e

echo "Enabling APM metrics for ${NR_APP_NAME}"

# Update the application name
sed -i "s/newrelic.appname = \"PHP Application\"/newrelic.appname = \"${NR_APP_NAME}\"/" /usr/local/etc/php/conf.d/newrelic.ini

newrelic-php5-$NR_AGENT_VERSION-linux-musl/newrelic-install install

mkdir -p /srv/storage/main/logs /srv/storage/main/framework/cache /srv/storage/main/framework/sessions /srv/storage/main/framework/views

chown -R www-data:www-data /srv/storage/main


# Ensure that the database is active
php -- "$DB_CONNECTION" "$DB_HOST" "$DB_PORT" "$DB_DATABASE" "$DB_USERNAME" "$DB_PASSWORD" <<'EOPHP'
<?php
$stderr = fopen('php://stderr', 'w');
for ($maxTries = 10;;) {
    try {
        $pdo = new PDO("$argv[1]:host=$argv[2];port=$argv[3];dbname=$argv[4]", $argv[5], $argv[6]);
        fwrite($stderr, 'Database connection was successful.'."\n");
        break;
    } catch (PDOException $e) {
        --$maxTries;
        if ($maxTries <= 0) {
            fwrite($stderr, 'Database connection failed.'."\n");
            exit(1);
        }
        fwrite($stderr, '['.$e->getMessage().'] Database connection failed. Trying again...'."\n");
        sleep(1);
	}
}
EOPHP

# Symlink everything that needs to be public
php /srv/app/artisan october:mirror /srv/app/public

# Initialize the database
php /srv/app/artisan october:up

exec "php-fpm"
