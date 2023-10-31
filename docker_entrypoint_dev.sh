#!/bin/bash

env

# Load Boilerplate secrets
echo [BPR] Writing secrets from Doppler to ${NOMAD_TASK_DIR}/doppler.env
doppler secrets download --no-file --format env > ${NOMAD_TASK_DIR}/doppler.env

echo [BPR] Loading secrets
set -o allexport
source ${NOMAD_TASK_DIR}/doppler.env
set +o allexport

env

# Install IAC tooling
npm --prefix tools/iac/filler install

# Start up asset compilation
cd assets && npm install && cd -
cd assets && npm run watch &

# Generate a certificate
[[ ! -e priv/cert/selfsigned.pem ]] && mix phx.gen.cert

# Reset feature flags
[[ ! -e .feature_flags_made ]] && \
	/usr/bin/redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" SADD "fun_with_flags" "internal_development" && \
	/usr/bin/redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" SADD "fun_with_flags" "new_ui" && \
	/usr/bin/redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" SADD "fun_with_flags" "recipient_use_fill_popup" && \
	/usr/bin/redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" HMSET  "fun_with_flags:new_ui" "boolean" "true" && \
	/usr/bin/redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" HMSET  "fun_with_flags:internal_development" "boolean" "true" && \
	/usr/bin/redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" HMSET  "fun_with_flags:recipient_use_fill_popup" "boolean" "true" && \
    touch .feature_flags_made

# Reset the database
[[ ! -e .database_made ]] && mix ecto.reset && touch .database_made

mix deps.get
mix ecto.migrate
mix phx.server
