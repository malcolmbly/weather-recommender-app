#!/usr/bin/env bash

set -o errexit

bundle install
bin/rails assets:precompile
bin/rails assets:clean

# Run migrations for primary database
bin/rails db:migrate

# Load Solid Queue schema into the queue database (same as primary in production)
bin/rails db:schema:load:queue