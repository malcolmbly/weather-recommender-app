#!/bin/bash
# bin/wait-for-db.sh

set -e

# These are the first three arguments: db, postgres, 5432
host="$1"
user="$2"
port="$3"

# Shift removes the first three arguments ($1, $2, $3) from $@,
# leaving only the actual command (bin/rails db:create db:migrate)
shift 3

echo "Checking database status..."

# Use the same reliable loop we built, but make it a reusable function
until PGPASSWORD=$POSTGRES_PASSWORD pg_isready -h "$host" -p "$port" -U "$user"; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up and running on $host:$port!"

# Now $1 is 'bin/rails', which is correct.
exec "$@"