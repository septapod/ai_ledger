#!/usr/bin/env bash
# exit on error
set -o errexit

echo "=== Setting up config files ==="
# Copy sample database config if needed (database.yml is gitignored)
if [ ! -f config/database.yml ]; then
  cp config/database.yml.sample config/database.yml
  echo "Created config/database.yml from sample"
fi

echo "=== Installing dependencies ==="
bundle install

echo "=== Precompiling assets ==="
bundle exec rails assets:precompile

echo "=== Cleaning assets ==="
bundle exec rails assets:clean

echo "=== Creating storage directories ==="
mkdir -p storage

echo "=== Setting up database ==="
# db:prepare creates the database if it doesn't exist, runs migrations if it does
bundle exec rails db:prepare

echo "=== Build complete ==="
