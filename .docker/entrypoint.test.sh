#!/bin/sh

set -e

php bin/console doctrine:database:create --if-not-exists --no-debug
php bin/console doctrine:migrations:migrate --no-interaction --no-debug
php bin/console doctrine:fixtures:load --no-interaction --no-debug

exec "$@"