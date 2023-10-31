#!/bin/bash

_cmd=${BOILERPLATE_COMMAND}

echo [BPR] Envvar dump:
echo "------- %< -------"
env
echo "------- >% -------"
echo [BPR] Running with command: ${_cmd}
echo [BPR] BOILERPLATE_DOCKER_DB_ADDR=${BOILERPLATE_DOCKER_DB_ADDR}
echo [BPR] About to wait 60 seconds for the DB to boot up

# Wait for the database to boot up
./tools/wait-for-it.sh -t 60 ${BOILERPLATE_DOCKER_DB_ADDR}

# Wait for Redis to boot up
echo [BPR] About to wait 60 seconds for redis to boot up
./tools/wait-for-it.sh -t 60 ${REDIS_HOST}:${REDIS_PORT}

# Seeding feature flags
if [[ $BOILERPLATE_NOMAD == 1  ]]; then
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "internal_development"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "new_ui"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "recipient_use_fill_popup"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "requestor_allow_template_creation"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "requestor_allow_checklist_creation"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "requestor_allow_template_edit"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "requestor_allow_checklist_edit"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "experiment_8289_21"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "audit_trail_v2"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "retention_testing"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "requestor_review_all"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "d2d_form_generation"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SADD "fun_with_flags" "automatic_bug_filling"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:new_ui" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:internal_development" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:recipient_use_fill_popup" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:requestor_allow_checklist_creation" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:requestor_allow_template_creation" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:requestor_allow_checklist_edit" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:requestor_allow_template_edit" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:experiment_8289_21" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:audit_trail_v2" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:retention_testing" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:d2d_form_generation" "boolean" "true"
	redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} HMSET  "fun_with_flags:automatic_bug_filling" "boolean" "true"

	# Setup the Erlang environment
	export RELEASE_COOKIE="boilerplate_nomad"
	export RELEASE_DISTRIBUTION="name"
	export RELEASE_NODE="redmine-${REDMINE_TICKET}@nomad.boilerplate.co"
fi

# Load Boilerplate secrets
echo [BPR] Writing secrets from Doppler to ${NOMAD_TASK_DIR}/doppler.env
doppler secrets download --no-file --format env > ${NOMAD_TASK_DIR}/doppler.env

echo [BPR] Loading secrets
set -o allexport
source ${NOMAD_TASK_DIR}/doppler.env
set +o allexport

echo [BPR] Dumping environment variables after reading it from Doppler
echo "------- %< -------"
env
echo "------- >% -------"

if [[ ${_cmd} == "migrate" ]]; then
	# Do a migration, then start the server
	echo [BPR] Executing migrations...
	/app/bin/boilerplate eval "BoilerPlate.Release.migrate"
	echo [BPR] Starting server...
	/app/bin/boilerplate start
elif [[ ${_cmd} == "create" ]]; then
	echo [BPR] Executing migrations...
	/app/bin/boilerplate eval "BoilerPlate.Release.migrate"
	echo [BPR] Executing the seed...
	/app/bin/boilerplate eval 'BoilerPlate.Release.seed(BoilerPlate.Repo, "seeds_nomad.exs")'
	echo [BPR] Executing the extra seed...
	/app/bin/boilerplate eval 'BoilerPlate.Release.seed(BoilerPlate.Repo, "seeds_nomad_extra.exs")'
	echo [BPR] Re-executing migrations...
	/app/bin/boilerplate eval "BoilerPlate.Release.migrate"
	echo [BPR] Starting server...
	/app/bin/boilerplate start
else
	# Otherwise, pass the argument directly to the binary
	echo [BPR] Passing the command to the release...
	/app/bin/boilerplate ${_cmd}
fi
