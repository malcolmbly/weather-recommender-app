#!/usr/bin/env bash

set -o errexit

bundle install
bin/rails assets:precompile
bin/rails assets:clean

# Run migrations (includes both app tables and Solid Queue tables)
# Since we're using a single database, db:migrate handles everything
bin/rails db:migrate