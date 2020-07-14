#!/bin/bash

set -e

if [[ $DATABASE_URL != *_test ]]; then
  echo "Database must be a test database";
  exit 1;
fi

php bin/console doctrine:database:create --if-not-exists --no-debug
php bin/console doctrine:migrations:migrate --no-interaction --no-debug
php bin/console doctrine:fixtures:load --no-interaction --no-debug

exec "$@"