#!/bin/sh

# Exit the script with code 0 when encountering errors
set -e

SUPERUSER_EMAIL=${DJANGO_SUPERUSER_EMAIL:-'admin@djangomail.com'}

if [ "$DATABASE" = "postgres" ]
then
    echo "Waiting for postgres at $SQL_HOST:$SQL_PORT..."
    RETRY_COUNT=0
    MAX_RETRIES=30
    while ! nc -z "$SQL_HOST" "$SQL_PORT"; do
      RETRY_COUNT=$((RETRY_COUNT + 1))
      if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Unable to connect to PostgreSQL at $SQL_HOST:$SQL_PORT after $MAX_RETRIES attempts."
        exit 1
      fi
      sleep 1
    done

    echo "PostgreSQL started successfully!"
fi

# Django collect static files
python manage.py collectstatic --no-input

# Deploy django server
if [ "$#" -gt 0 ]; then
    exec "$@"
else
    exec gunicorn console.wsgi:application --bind 0.0.0.0:8000
fi

