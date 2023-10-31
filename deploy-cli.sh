#!/bin/bash

shopt -s extglob
_ticket=$1

# Configuration
brian=6
prem=24

nomad_tester_id=${brian} # Deprecated, Nomad testing now automatically goes to the ticket creator
eng_tester_id=${prem}
app_tester_id=${prem}

# Redmine Configuration
deployment_field_id=11
dri_field_id=15
status_design_review=13
status_staging=14
status_deploy=15
status_verify=5

# Constants and other secret stuff
export NOMAD_ADDR="http://eng.boilerplate.co:4646"
export BLPT_API_KEY="798076dc8fcec583db486d4d2092a63f749cc8118000990296dec62e7e9486ce"
export BLPT_REDMINE="https://bugs.boilerplate.co"
export BLPT_REDMINE_API_KEY="b3c99682eedc42ff3e7fef099ffdcd10341ae3c4"
export BLPT_REDMINE_NONVPN="https://bugs.internal.boilerplate.co"
export BLPT_S3_BUCKET_LOGS="boilerplate-logs"
export DEPLOY_CLI_SERVICE="https://service-deploy-cli.nomad.boilerplate.co"
export DEPLOY_CLI_SERVICE_NONVPN="https://service-deploy-cli.internal.boilerplate.co"
export DEPLOY_CLI_SLACK_HOOK="https://hooks.slack.com/services/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"
export DEPLOY_CLI_SLACK_HOOK_CI="https://hooks.slack.com/services/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"

# Misc
TAB_CHAR="###"

###
### Library of Functions
###

joinByString() {
    local separator="$1"
    shift
    local first="$1"
    shift
    printf "%s" "$first" "${@/#/$separator}"
}

###
### Code
###

function usage {
    BACKEND_VERSION=$(curl -s -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
	    		      -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" ${DEPLOY_CLI_SERVICE_NONVPN}/version)
    BACKEND_ONLINE=$?
    echo "Usage:"
    if [[ $BLPT_USERNAME != "" ]]; then
       echo ""
       echo "Note: You are currently logged in to the deploy infrastructure as \`$BLPT_USERNAME\`"
       if [[ ${BACKEND_ONLINE} == 0 ]]; then
           echo "      Backend is running version ${BACKEND_VERSION}"
       else
           echo "      Backend is currently offline!"
       fi
    else
        echo ""
        echo "Note: To start using this script, you need to login first with '$0 login."
    fi
    echo ""
    echo "Misc Commands"
    echo "  $0 login             <--- Authenticate yourself with deploy_cli"
    echo "  $0 list              <--- List current deployments"
    echo "  $0 tickets <tag>     <--- Show the Redmine tickets that are part of the TAG"
    echo "  $0 status            <--- Get a system status overview"
    echo ""
    echo "Deploying to Nomad"
    echo "  $0 <redmine>         <--- Deploys the current source tree as ticket REDMINE to Nomad for testing."
    echo "  $0 stop <redmine>    <--- Stops the latest deployment of REDMINE ticket on Nomad"
    echo "  $0 ci <redmine>      <--- Submit the current branch to the CI"
    echo ""
    echo "Deploying to Eng or App"
    echo "  $0 build <tickets..>          <--- Builds the current source tree and gives you a tag."
    echo "  $0 deploy eng <tag>           <--- Deploys the provided TAG to Eng"
    echo "  $0 deploy app <tag>           <--- Deploys the provided TAG to App, this requires approval."
    echo "  $0 deploy-remote <ins> <tag>  <--- Deploys the provided remote TAG to INS."
    echo "  $0 sign <tag>                 <--- Signs an App TAG, finalizing deployment (requires authorization)"
    echo ""
    echo "Logs"
    echo "  $0 logs stdout <deployment> <--- Get stdout logs for a deployment (boilerplate-XXXX, app, eng)"
    echo "  $0 logs stderr <deployment> <--- Get stderr logs for a deployment (boilerplate-XXXX, app, eng)"
    echo ""
    echo "Ticket Management"
    echo "  $0 staging           <--- Show staging (live on Eng, but not on App) tickets"
    echo ""
    echo "History"
    echo "  $0 tags                    <--- Get latest tags"
    echo "  $0 latest <instance>       <--- Get latest deployments to INSTANCE"
    echo "  $0 revert <instance> <tag> <--- Revert INSTANCE to TAG"
    echo ""
    echo "Emergency Use"
    echo "  $0 create <tag>         <--- Creates a TAG on the backend, without deployment"
    echo "  $0 nomad test <name>    <--- Creates a new Nomad instance for testing Nomad"
    echo "  $0 nomad stop <name>    <--- Stops a previously deployed test Nomad instance"
    echo "  $0 emergency <tag>      <--- Deploys the TAG to App without marking any tickets as pushed"
    echo "  $0 grab-remote <tag>    <--- Pulls and retags a remote tag"
    echo ""
    echo "Environment variables"
    echo "  DEPLOY_CLI_BRANCH_OVERRIDE         <--- If set to 1, allows deploying to Eng/App"
    echo "                                          from a branch other than master."
    echo "  DEPLOY_CLI_NO_TICKET_OVERRIDE      <--- If set to 1, allows deploying a tag without"
    echo "                                          associated Redmine tickets."
    echo "  DEPLOY_CLI_NO_UPDATE_SLACK         <--- If set to 1, do not announce anything on Slack."
    echo "  DEPLOY_CLI_NO_UPDATE_REDMINE       <--- If set to 1, do not change anything on Redmine."
    echo "  DEPLOY_CLI_NO_UPDATE_BACKEND       <--- If set to 1, do not change anything on the backend."
    echo "  DEPLOY_CLI_IGNORE_ALREADY_DEPLOYED <--- If set to 1, allow re-deploying a tag."
    echo ""
    echo "Currently, we support Exodus on all instances."
	exit
}

function login {
    echo "Please enter your Boilerplate username (the part of your @boilerplate.co email, before the @)"
    echo ""
    echo -n "BLPT Username: "
    read blpt_username
    echo "export BLPT_USERNAME=${blpt_username}" > .deploy-cli.cfg
    echo "Please enter your deploy key (ask Lev)."
    echo ""
    echo -n "BLPT Deploy Key: "
    read blpt_deploy_key
    echo "export BLPT_DEPLOY_KEY=${blpt_deploy_key}" >> .deploy-cli.cfg
    echo "Type 1 if you would like to try Non-VPN Deploys (BETA), or 0 if not."
    echo -n "Try Non-VPN Deploy feature: "
    read blpt_non_vpn
    echo "export BLPT_NONVPN=${blpt_non_vpn}" >> .deploy-cli.cfg
    echo "Settings saved, you are now logged in."
    exit
}

function list {
    tickets=$(nomad job status | \
        grep 'running' | \
        grep -Ee 'boilerplate-[0-9]+' | \
        cut -d' ' -f1 | \
        cut -d'-' -f2)
    staging_output="TICKET${TAB_CHAR}STATUS${TAB_CHAR}TESTING?${TAB_CHAR}SUBJECT####"
    for ticket in ${tickets}
    do
    	    print_ticket_status_with_subject ${ticket} 2
	    staging_output="${staging_output}${ticket}${TAB_CHAR}${_output}####"
    done
    echo ${staging_output} | sed 's/####/\n/g' | column -ts '###'
    exit
}

function node_status {
    if [[ ${BLPT_NONVPN} == 1 ]]; then
	    echo "This command requires the VPN to be configured."
	    exit 1
    else
	    nomad node status
	    exit
    fi
}

function check_config {
    if [[ ! -e .deploy-cli.cfg ]]
    then
        echo "Please login to deploy-cli by running '$0 login'"
	if [[ ${check_config_do_exit} == 1 ]]; then
		exit 1
	fi
	export BLPT_NONVPN=1
    fi

    if [[ ${BLPT_NONVPN} == 1 ]];
    then
	    echo "[INFO] Currently configured to try deploying without a VPN. If it doesn't work, please let Lev know."
	    export DEPLOY_CLI_SERVICE=${DEPLOY_CLI_SERVICE_NONVPN}
	    export BLPT_REDMINE=${BLPT_REDMINE_NONVPN}

	    mitmdump \
		    -q \
		    -s tools/mitm-boilerplate-api-key.py \
		    -p 57548 \
		    --mode reverse:nomad.internal.boilerplate.co >mitmdump.log 2>mitmdump.log &

	    export NOMAD_ADDR="http://localhost:57548"
    fi

   if [[ ! -z ${BLPT_RUNNING_IN_CI} ]];
   then
          echo "[INFO] Running in CI mode"
          export BLPT_USERNAME=${BOILERPLATE_CI_USER}
   fi

    redmine_uid=$(curl --fail -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" ${DEPLOY_CLI_SERVICE}/redmineid/${BLPT_USERNAME} 2>/dev/null)
    if [[ $? != 0 ]]
    then
        echo "Invalid deploy key, please login again"
        exit 1
    fi

    export BLPT_REDMINE_USER_ID=${redmine_uid}
}

function stop_redmine {
    _tck=$1
    if [[ ${_tck} == "" ]]
    then
        echo "Error: Please supply the redmine ticket number to this command, example:"
        echo ""
        echo "  $0 stop 1234"
        echo ""
        echo "The above will stop the Nomad instance for Redmine ticket 1234"
        exit
    fi

    if [[ ${_tck} == "app" || ${_tck} == "eng" ]]
    then
        echo "Error: Please provide a Redmine ticket number instead of trying to stop App or Eng."
        exit 1
    fi

    nomad job stop boilerplate-${_tck}
    if [[ $? == 0  ]];
    then
        update_slack "nomad_stopped" ${_tck}
        update_redmine "nomad_stopped" ${_tck}
    fi
    exit
}

function check_dependencies {
    if ! command -v docker &> /dev/null
    then
        echo "docker is not installed, please install Docker: https://docs.docker.com/get-docker/"
        exit
    fi

    if ! command -v aws &> /dev/null
    then
        echo "aws-cli is not installed, please install AWS CLI: https://aws.amazon.com/cli/"
        exit
    fi

    if ! command -v jq &> /dev/null
    then
        echo "jq is not installed, please install jq: https://stedolan.github.io/jq/download/"
        exit
    fi

    if ! command -v nomad &> /dev/null
    then
        echo "nomad is not installed, please install nomad: https://learn.hashicorp.com/tutorials/nomad/get-started-install?in=nomad/get-started"
        exit
    fi

    if ! command -v curl &> /dev/null
    then
        echo "curl is not installed, please install cURL, use google to find out how."
        exit
    fi

    if ! command -v sed &> /dev/null
    then
        echo "sed is not installed, please install sed, use google to find out how."
        exit
    fi

    if ! command -v mktemp &> /dev/null
    then
        echo "mktemp is not installed, please install mktemp, use google to find out how."
        exit
    fi

    if ! command -v mitmdump &> /dev/null
    then
        echo "mitmproxy is not installed, please install mitmproxy, see: https://mitmproxy.org/"
        exit
    fi

}

function print_available_instances {
        echo "Available instances:"
        echo "  - eng (staging, no approval needed)"
        echo "  - app (production, 1 signature needed)"
}

function ship_logs {
  log_instance=$1
  # Ship the current logs to 
  #   Find the location on the logs first.
  #   Merge the logs files together.
  #   Upload the file to S3.
  log_timestamp=$(date +"%s")
  log_filename_stdout="stdout-${log_timestamp}.log"
  log_filename_stderr="stderr-${log_timestamp}.log"
  log_filename_telemetry="telemetry-${log_timestamp}.json"
  log_folder="instance-logs/${log_instance}"
  echo [ship_logs] Shipping Logs for ${log_instance}: stdout ${log_filename_stdout}, stderr ${log_filename_stderr}
  old_alloc_id=$(curl -s ${NOMAD_ADDR}/v1/allocations | jq -r "map(select(.JobID == \"boilerplate-${log_instance}\")) | map(select(.TaskGroup == \"webs\")) | sort_by(.CreateTime) | map(.ID) | .[-1]")
  echo [ship_logs] Allocation of deployment: ${old_alloc_id}
  nomad alloc logs ${old_alloc_id} boilerplate > /tmp/${log_filename_stdout}
  nomad alloc logs -stderr ${old_alloc_id} boilerplate > /tmp/${log_filename_stderr}
  aws s3 cp /tmp/${log_filename_stdout} s3://${BLPT_S3_BUCKET_LOGS}/${log_folder}/${log_filename_stdout} && rm /tmp/${log_filename_stdout}
  aws s3 cp /tmp/${log_filename_stderr} s3://${BLPT_S3_BUCKET_LOGS}/${log_folder}/${log_filename_stderr} && rm /tmp/${log_filename_stderr}
  echo [ship_logs] Done shipping logs.
  echo [ship_logs/telemetry] Grabbing telemetry data
  curl \
      -k \
      -XPOST https://${log_instance}.boilerplate.co/n/api/v1/internal/telemetry \
      -H "Content-Type: application/json" \
      -d '{"key": "fde543ea9918024cdc58105cd2c1042db5e2af6ddb6c24c4d46e1ad4de34f0e5"}' > /tmp/__boilerplate_telemetry.json
  aws s3 cp /tmp/__boilerplate_telemetry.json s3://${BLPT_S3_BUCKET_LOGS}/${log_folder}/${log_filename_telemetry} && rm /tmp/__boilerplate_telemetry.json
  echo [ship_logs/telemetry] Done uploading telemetry data
}

function deploy {
    deploy_target=$1
    if [[ ${deploy_target} == "" ]]; then
        echo "Error: Please supply the instance name to this command, example:"
        echo ""
        echo "  $0 deploy eng"
        echo ""
        print_available_instances
        exit 1;
    fi

    if [[ ${deploy_target} != "eng" && ${deploy_target} != "app" ]]; then
        echo "Error: Invalid target for deployment"
        echo ""
        print_available_instances
        exit 1
    fi

    _image_hash=$2
    _aws_image="418430805305.dkr.ecr.us-east-2.amazonaws.com/${_image_hash}"

    docker pull ${_aws_image} >/dev/null 2>&1
    if [[ $? != 0 ]]
    then
        echo "Error: The tag provided does not seem to exist."
        echo ""
        echo "Tried to pull ${_aws_image}"
        exit 1
    fi

    tickets=$(curl -s \
        --fail \
        -k \
        -H 'Content-Type: application/json' \
        -XGET \
	 -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
        ${DEPLOY_CLI_SERVICE}/tag/${_image_hash} \
        | jq -r '.tickets')
    if [[ $? != 0 || $tickets == "" ]]
    then
        tickets=$(docker inspect ${_aws_image} | jq --raw-output '.[0].Config.Labels.redmine')
        if [[ $tickets == "" && ${DEPLOY_CLI_NO_TICKET_OVERRIDE} == "" ]]
        then
            echo "Error: The tag provided does not have any Redmine tickets associated with it."
            echo "       This behavior can be overriden using DEPLOY_CLI_NO_TICKET_OVERRIDE=1 but"
            echo "       there can be unintended sideeffects."
            exit 1
        fi
    fi

    # Check if the tag was already deployed
    curl -s \
        --fail \
        -k \
        -H 'Content-Type: application/json' \
        -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
        ${DEPLOY_CLI_SERVICE}/deployment/${deploy_target}/${_image_hash} > /dev/null
    if [[ $? == 0 ]]; then
        echo Error: Tag ${_image_hash} was already deployed to instance ${deploy_target}
	if [[ ${DEPLOY_CLI_IGNORE_ALREADY_DEPLOYED} == "" ]]
	then
		exit 1
	fi
    fi

    echo The provided image has the following tickets: ${tickets}

    case ${deploy_target} in
        eng)
            # Deploy to Eng
            password=$(aws ecr get-login-password --region us-east-2)
            
            ship_logs eng
            
            # Submit the job to nomad
            nomad job run \
                -var="boilerplate_image=${_aws_image}" \
                -var="boilerplate_hash=${_image_hash}" \
                -var="aws_key=${password}" \
                nomad/boilerplate-eng.nomad

            if [[ $? != 0 ]]
            then
                echo "Error: Failed to deploy to Eng, see above for details."
                exit 1
            fi

            update_backend "deployed" ${_image_hash} ${deploy_target} "${tickets}"

            webs_alloc_id=$(curl -s ${NOMAD_ADDR}/v1/allocations | jq -r "map(select(.JobID == \"boilerplate-eng\")) | map(select(.TaskGroup == \"webs\")) | sort_by(.CreateTime) | map(.ID) | .[-1]")
            echo Boilerplate ENG Allocation ID: ${webs_alloc_id}

            log_url="https://nomad.internal.boilerplate.co/ui/allocations/${webs_alloc_id}/fs/alloc/logs"
            tickets_formatted=()
            for ticket in ${tickets}; do
                tickets_formatted+=("<${BLPT_REDMINE}/issues/${ticket}|#${ticket}>")

                update_redmine "eng_deployed" ${ticket} ${_image_hash}
            done

            # No longer needed as the backend will update Slack.
            # update_slack "eng_deployed" ${_image_hash} " " ${webs_alloc_id}

            echo Logs for this deployment can be found at ${log_url}
            echo Keep in mind that it may take a minute or two for Eng to be available and operational.
            exit 0;
            ;;
        app)
            # Check if the tag was signed
            curl -s \
                --fail \
                -H 'Content-Type: application/json' \
                -XGET \
                -d '{"tag": "'${_image_hash}'"}' \
		 -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
                ${DEPLOY_CLI_SERVICE}/sign

            if [[ $? != 0  ]]
            then
                echo "Error: The tag you provided isn't signed or doesn't exist."
                echo ""
                echo "Please request manager approval before trying to deploy to App."
                exit 1
            fi

            # Deploy to App
            password=$(aws ecr get-login-password --region us-east-2)
            
            ship_logs app
            
            # Submit the job to nomad
            nomad job run \
                -var="boilerplate_image=${_aws_image}" \
                -var="boilerplate_hash=${_image_hash}" \
                -var="aws_key=${password}" \
                nomad/boilerplate-app.nomad

            if [[ $? != 0 ]]
            then
                echo "Error: Failed to deploy to App, see above for details."
                exit 1
            fi

            update_backend "deployed" ${_image_hash} ${deploy_target} "${tickets}"

            webs_alloc_id=$(curl -s ${NOMAD_ADDR}/v1/allocations | jq -r "map(select(.JobID == \"boilerplate-app\")) | map(select(.TaskGroup == \"webs\")) | sort_by(.CreateTime) | map(.ID) | .[-1]")
            echo Boilerplate APP Allocation ID: ${webs_alloc_id}

            log_url="https://nomad.internal.boilerplate.co/ui/allocations/${webs_alloc_id}/fs/alloc/logs"
            tickets_formatted=()
            for ticket in ${tickets}; do
                tickets_formatted+=("<${BLPT_REDMINE}/issues/${ticket}|#${ticket}>")
            done

            if [[ ${_DEPLOY_CLI_EMERGENCY} == "" ]]; then
                push_unpushed_tickets ${_image_hash}
                # update_slack "app_deployed" ${_image_hash} " " ${webs_alloc_id}
            else
                update_slack "emergency_app_deployed" ${_image_hash} " " ${webs_alloc_id}
                for ticket in ${tickets}; do
                    update_redmine "emergency_app_deployed" ${ticket} ${_image_hash}
                done
            fi


            echo Uploading the source maps to Rollbar...
            ./tools/upload_rollbar.sh ${_image_hash} `curl -s -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" ${DEPLOY_CLI_SERVICE}/secret/rollbar_key`

            echo Telling Rollbar about the deploy...
            update_rollbar ${_image_hash} "production"

            echo Logs for this deployment can be found at ${log_url}
            echo Keep in mind that it may take a minute or two for App to be available and operational.
            exit 0;
            ;;
    esac
}

function _internal_update_backend {
    action=$1
    tag=$2
    instance=$3
    _iub_tickets=$4

    echo "Updating internal_backend with action=${action} tag=${tag} instance=${instance} tickets='${_iub_tickets}'"

    case ${action} in
        new_tag)
            _data='{"tag": "'${tag}'", "tickets": "'${_iub_tickets}'"}'
            echo _data=${_data}
            curl -XPOST \
                -s \
                -H 'Content-Type: application/json' \
                -d "${_data}" \
		-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
                "${DEPLOY_CLI_SERVICE}/tag"
            ;;
        new_deployment)
            _data='{"tag": "'${tag}'", "instance": "'${instance}'", "user": "'${BLPT_USERNAME}'"}'
            echo _data=${_data}
            curl -XPOST \
                -s \
                -H 'Content-Type: application/json' \
                -d "${_data}" \
		-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
                "${DEPLOY_CLI_SERVICE}/deploy"
            ;;
	ci_finished)
	    _data='{"build_id": "'${BOILERPLATE_BUILD_ID}'", "status": 1, "tag": "'${tag}'"}'
	    echo _data=${_data}
            curl -XPUT \
                -s \
                -H 'Content-Type: application/json' \
                -d "${_data}" \
		-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
                "${DEPLOY_CLI_SERVICE}/ci"
	    ;;
    esac
}

function update_backend {
    action=$1
    tag=$2
    _ub_instance=$3
    _ub_tickets=$4

    if [[ ${DEPLOY_CLI_NO_UPDATE_BACKEND} != "" ]]
    then
        echo "Skipping backend update due to DEPLOY_CLI_NO_UPDATE_BACKEND being set"
    else
        echo "Updating backend with action=${action} tag=${tag} _ub_instance=${_ub_instance} _ub_tickets='${_ub_tickets}'"

        case ${action} in
            deployed)
                _internal_update_backend "new_tag" ${tag} "" "${_ub_tickets}"
                _internal_update_backend "new_deployment" ${tag} ${_ub_instance}
                ;;
	    ci_finished)
		_internal_update_backend "ci_finished" ${tag} "" ""
	        ;;
        esac
    fi
}

function update_rollbar {
    rollbar_token=$(curl -s -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" ${DEPLOY_CLI_SERVICE}/secret/rollbar_key)

    curl -s \
        -XPOST \
        -H 'Content-Type: application/json' \
        -H "X-Rollbar-Access-Token: ${rollbar_token}" \
        -d '{"environment": "'$2'", "revision": "'$1'"}' \
        https://api.rollbar.com/api/1/deploy
}

function update_slack {
    if [[ ${DEPLOY_CLI_NO_UPDATE_SLACK} == "" ]]
    then
        case $1 in 
            nomad_stopped)
                curl -s \
                    -XPOST \
                    -H 'Content-Type: application/json' \
                    ${DEPLOY_CLI_SLACK_HOOK} \
                    -d "{\"text\": \"Nomad deployment for Ticket <${BLPT_REDMINE_NONVPN}/issues/${2}|#${2}> was STOPPED by ${BLPT_USERNAME}.\",\"username\": \"deploy-cli\",\"icon_emoji\":\"coffee\"}" \
                    >/dev/null
                ;;
            eng_deployed)
                curl -s \
                    -XPOST \
                    -H 'Content-Type: application/json' \
                    ${DEPLOY_CLI_SLACK_HOOK} \
                    -d "{\"text\": \"Tag ${2} (tickets: ${tickets_formatted[@]}) was deployed to Eng (allocation ${4}) by ${BLPT_USERNAME}\",\"username\": \"deploy-cli\",\"icon_emoji\":\"coffee\"}" \
                    >/dev/null
                ;;
            app_deployed)
                curl -s \
                    -XPOST \
                    -H 'Content-Type: application/json' \
                    ${DEPLOY_CLI_SLACK_HOOK} \
                    -d "{\"text\": \":white_check_mark: Tag ${2} (tickets: ${tickets_formatted[@]}) was deployed to App (allocation ${4}) by ${BLPT_USERNAME}\",\"username\": \"deploy-cli\",\"icon_emoji\":\"coffee\"}" \
                    >/dev/null
                ;;
            emergency_app_deployed)
                curl -s \
                    -XPOST \
                    -H 'Content-Type: application/json' \
                    ${DEPLOY_CLI_SLACK_HOOK} \
                    -d "{\"text\": \":warning: Tag ${2} (tickets: ${tickets_formatted[@]}) was deployed to App as per *emergency protocols* (allocation ${4}) by ${BLPT_USERNAME}\",\"username\": \"deploy-cli\",\"icon_emoji\":\"coffee\"}" \
                    >/dev/null
                ;;
            nomad_deployed)
                curl -s \
                    -XPOST \
                    -H 'Content-Type: application/json' \
                    ${DEPLOY_CLI_SLACK_HOOK} \
                    -d "{\"text\": \"Ticket <${BLPT_REDMINE_NONVPN}/issues/${2}|#${2}> was deployed to Nomad (allocation ${3}) by ${BLPT_USERNAME}, URL: ${4}\",\"username\": \"deploy-cli\",\"icon_emoji\":\"coffee\"}" \
                    >/dev/null
                ;;
            tag_signed)
                curl -s \
                    -XPOST \
                    -H 'Content-Type: application/json' \
                    ${DEPLOY_CLI_SLACK_HOOK} \
                    -d "{\"text\": \":warning: Tag \`${2}\` was signed by ${BLPT_USERNAME}. :warning:\",\"username\": \"deploy-cli\",\"icon_emoji\":\"coffee\"}" \
                    >/dev/null
                ;;
            ci_finished_eng)
                curl -s \
                    -XPOST \
                    -H 'Content-Type: application/json' \
                    ${DEPLOY_CLI_SLACK_HOOK_CI} \
                    -d "{\"text\": \":white_check_mark: Tag \`${2}\` was built using the CI, ready for Eng. :white_check_mark:\",\"username\": \"deploy-cli\",\"icon_emoji\":\"coffee\"}" \
                    >/dev/null
                ;;
        esac
    else
        echo "Warning: Skipping Slack update to due to DEPLOY_CLI_NO_UPDATE_SLACK being set."
    fi
}

function update_redmine {
    action=$1
    ticket=$2
    tag=$3
    _ur_log_url=$4

    if [[ ${DEPLOY_CLI_NO_UPDATE_REDMINE} == "" ]];
    then
        case ${action} in
            eng_deployed)
                curl -s \
                    -k \
                    -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
		    -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
                    -H 'Content-Type: application/json' \
                    ${BLPT_REDMINE}/issues/${ticket}.json \
                    -XPUT \
                    -d '{"issue": {"status_id": "'${status_staging}'", "assigned_to_id": "'${eng_tester_id}'", "custom_fields": [{"value": "'${tag}'", "id": "'${deployment_field_id}'"}], "notes": "This ticket was deployed to Eng as part of tag `'${tag}'` by '${BLPT_USERNAME}'"}}'
            ;;
            app_deployed)
                curl -s \
                    -k \
                    -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
                    -H 'Content-Type: application/json' \
		    -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
                    ${BLPT_REDMINE}/issues/${ticket}.json \
                    -XPUT \
                    -d '{"issue": {"status_id": "'${status_verify}'", "assigned_to_id": "'${app_tester_id}'", "custom_fields": [{"value": "'${tag}'", "id": "'${deployment_field_id}'"}], "notes": "This ticket was deployed to App as part of tag `'${tag}'` by '${BLPT_USERNAME}'"}}'
                ;;
            emergency_app_deployed)
                curl -s \
                    -k \
                    -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
                    -H 'Content-Type: application/json' \
		    -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
                    ${BLPT_REDMINE}/issues/${ticket}.json \
                    -XPUT \
                    -d '{"issue": {"status_id": "'${status_verify}'", "assigned_to_id": "'${app_tester_id}'", "custom_fields": [{"value": "'${tag}'", "id": "'${deployment_field_id}'"}], "notes": "This ticket was deployed to App UNDER EMERGENCY CONDITIONS as part of tag `'${tag}'` by '${BLPT_USERNAME}'"}}'
                ;;
            nomad_stopped)
                curl -s \
                    -k \
                    -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
		    -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
                    -H 'Content-Type: application/json' \
                    ${BLPT_REDMINE}/issues/${ticket}.json \
                    -XPUT \
                    -d '{"issue": {"notes": "Nomad deployment was stopped by '${BLPT_USERNAME}'"}}'
                ;;
            nomadified)
                nomad_url=$tag
                _ur_log_url=${_ur_log_url}
                # Grab the ticket creator
                echo BOILERPLATE_CI_ASSIGNEE=${BOILERPLATE_CI_ASSIGNEE}
                if [[ -z "${BLPT_RUNNING_IN_CI}" ]] || [[ ${BOILERPLATE_CI_ASSIGNEE} == 0 ]]; then
                    ticket_creator_id=$(curl -s \
                        -k \
                        -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
                        -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
                        -H 'Content-Type: application/json' \
                        ${BLPT_REDMINE}/issues/${ticket}.json \
                        | jq '.issue.author.id')
                    curl -s \
                        -k \
                        -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
                        -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
                        -H 'Content-Type: application/json' \
                        ${BLPT_REDMINE}/issues/${ticket}.json \
                        -XPUT \
                        -d '{"issue": {"status_id": "'${status_design_review}'", "assigned_to_id": "'${ticket_creator_id}'", "custom_fields": [{"value": ['${BLPT_REDMINE_USER_ID}'], "id": "'${dri_field_id}'"}, {"value": "'${nomad_url}'", "id": "'${deployment_field_id}'"}], "notes": "This ticket was deployed to Nomad URL '${nomad_url}' by '${BLPT_USERNAME}', logs are at '${_ur_log_url}'"}}'
                else
                    curl -s \
                        -k \
                        -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
                        -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
                        -H 'Content-Type: application/json' \
                        ${BLPT_REDMINE}/issues/${ticket}.json \
                        -XPUT \
                        -d '{"issue": {"status_id": "'${status_design_review}'", "assigned_to_id": "'${BOILERPLATE_CI_ASSIGNEE}'", "custom_fields": [{"value": ['${BLPT_REDMINE_USER_ID}'], "id": "'${dri_field_id}'"}, {"value": "'${nomad_url}'", "id": "'${deployment_field_id}'"}], "notes": "This ticket was deployed to Nomad URL '${nomad_url}' by '${BLPT_USERNAME}', logs are at '${_ur_log_url}'"}}'
                fi
            ;;
        esac
    else
        echo "Warning: Skipping Redmine update to due to DEPLOY_CLI_NO_UPDATE_REDMINE being set."
    fi
}

function build_docker {
    _image_hash=$1
    redmine_tickets=$2
    _aws_image="418430805305.dkr.ecr.us-east-2.amazonaws.com/${_image_hash}"

    # Build the image
    if [[ -z "${BLPT_RUNNING_IN_CI}" ]]; then
	    aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 418430805305.dkr.ecr.us-east-2.amazonaws.com
    fi

    docker build \
        --label "redmine=${redmine_tickets}" \
        --label "blptuser=${BLPT_USERNAME}" \
        -t ${_image_hash} \
        .

    if [[ $? != 0 ]]; then
        echo "Error: failed to build the Docker container, please see the logs above for clues on how to proceed."
        exit 1
    fi
    docker tag ${_image_hash} ${_aws_image} 
    docker push ${_aws_image}
}

function build_start {
    _redmine_tickets=$1
    _git_hash=$(git rev-parse --short HEAD)
    current_describe=$(git describe HEAD)
    _timestamp=$(date "+%s")
    _image_hash="boilerplate:${_timestamp}-${_git_hash}"

    if [[ ${_redmine_tickets} == "" ]]
    then
        echo ""
        echo "Error: No redmine ticket(s) provided."
        echo ""
        echo "Please provide the ticket(s) that you are building, like this:"
        echo "  $0 build 1234 1337"
        exit 1
    fi

    echo "Building \`${current_describe}\` (tickets: ${_redmine_tickets}) as '${_image_hash}'..."

    current_branch=$(git branch --show-current)
    if [[ ${current_branch} != "master" && $DEPLOY_CLI_BRANCH_OVERRIDE == "" ]]; then
        echo ""
        echo "Error: As a cautionary measure, only the \`master\` branch can be built as a Docker container."
        echo "       This behavior can be overriden using DEPLOY_CLI_BRANCH_OVERRIDE=1 but please be aware"
        echo "       that this may have unintended sideeffects."
        echo "Please make sure your work is merged into master and your current git branch is master before running this command".
        exit 1
    fi

    build_docker ${_image_hash} "${_redmine_tickets}"

    echo ""
    echo ""
    echo "SUCCESSFULLY BUILT: The resulting tag is ${_image_hash}"
    echo ""
    echo "To deploy this tag to Eng, use: $0 deploy eng ${_image_hash}"
    echo "                   to App, use: $0 deploy app ${_image_hash}"
    echo ""
    echo "To sign this tag for deployment for App, ask your manager to run the following command after deploying this to Eng"
    echo "    $0 sign ${_image_hash}"

    if [[ ! -z "${BLPT_RUNNING_IN_CI}" ]]; then
        update_slack "ci_finished_eng" ${_image_hash}
	update_backend "ci_finished" ${_image_hash} "" ""
    fi

    exit 0
}

function build_redmine {
    _ticket=$1
    _tag="boilerplate:redmine-${_ticket}"

    echo "Deploying the current source tree as Redmine ticket ${_ticket} to Nomad..."
    build_docker "${_tag}" "${_ticket}"

    # Create the job.
    sed -e "s/XXXREDMINETICKETXXX/${_ticket}/g" < nomad/boilerplate.nomad > nomad/boilerplate-${_ticket}.nomad

    # Replace the login
    #kpassword=$(aws ecr get-login-password --region us-east-2)
    #ksed -e "s/XXXAWSKEYXXX/${password}/g" < nomad/boilerplate-${_ticket}.nomad > nomad/boilerplate-${_ticket}-2.nomad
    #krm nomad/boilerplate-${_ticket}.nomad

    #kmv nomad/boilerplate-${_ticket}-2.nomad nomad/boilerplate-${_ticket}.nomad

    # Submit the job to nomad
    nomad job run \
        -var="boilerplate_image=${_aws_image}" \
        -var="boilerplate_hash=${_tag}" \
        nomad/boilerplate-${_ticket}.nomad

    webs_alloc_id=$(curl -s ${NOMAD_ADDR}/v1/allocations | jq -r "map(select(.JobID == \"boilerplate-${_ticket}\")) | map(select(.TaskGroup == \"webs\")) | sort_by(.CreateTime) | map(.ID) | .[-1]")
    echo Boilerplate Allocation ID: ${webs_alloc_id}

    url="https://boilerplate-${_ticket}.internal.boilerplate.co/"
    log_url="https://nomad.internal.boilerplate.co/ui/allocations/${webs_alloc_id}/fs/alloc/logs"

    update_slack "nomad_deployed" ${_ticket} ${webs_alloc_id} ${url}
    update_redmine "nomadified" ${_ticket} ${url} ${log_url}

    rm nomad/boilerplate-${_ticket}.nomad

    if [[ ! -z "${BLPT_RUNNING_IN_CI}" ]]; then
	update_backend "ci_finished" "boilerplate:redmine-${_ticket}" "" ""
    fi

    echo Deployment can be checked at ${url}
    echo Logs for this deployment can be found at ${log_url}
    echo Keep in mind that it may take a minute or two for your instance to be available and operational.
    exit 0
}

function stop_nomad_test {
    _tck=$1
    if [[ ${_tck} == "" ]]
    then
        echo "Error: Please supply the name of the deployment."
        echo ""
        echo "  $0 stop levtest"
        exit
    fi

    if [[ ${_tck} == "app" || ${_tck} == "eng" ]]
    then
        echo "Error: Do not try to stop app or eng, please."
        exit 1
    fi

    nomad job stop boilerplate-${_tck}
    exit
}

function build_nomad_test {
    _ticket=$1
    _timestamp=$(date "+%s")
    _tag="boilerplate:nomad-test-${_timestamp}-${_ticket}"

    echo "Deploying the current source tree for testing Nomad instances: ${_tag}"
    build_docker "${_tag}" "${_ticket}"

    # Create the job.
    sed -e "s/XXXREDMINETICKETXXX/${_ticket}/g" < nomad/boilerplate.nomad > nomad/boilerplate-${_ticket}.nomad

    # Replace the login
    password=$(aws ecr get-login-password --region us-east-2)
    sed -e "s/XXXAWSKEYXXX/${password}/g" < nomad/boilerplate-${_ticket}.nomad > nomad/boilerplate-${_ticket}-2.nomad
    rm nomad/boilerplate-${_ticket}.nomad

    mv nomad/boilerplate-${_ticket}-2.nomad nomad/boilerplate-${_ticket}.nomad

    # Submit the job to nomad
    nomad job run \
        -var="boilerplate_image=${_aws_image}" \
        -var="boilerplate_hash=${_tag}" \
        nomad/boilerplate-${_ticket}.nomad

    webs_alloc_id=$(curl -s ${NOMAD_ADDR}/v1/allocations | jq -r "map(select(.JobID == \"boilerplate-${_ticket}\")) | map(select(.TaskGroup == \"webs\")) | sort_by(.CreateTime) | map(.ID) | .[-1]")
    echo Boilerplate Allocation ID: ${webs_alloc_id}

    # Grab port map from the allocation
    url="https://boilerplate-${_ticket}.internal.boilerplate.co/"
    log_url="https://nomad.internal.boilerplate.co/ui/allocations/${webs_alloc_id}/fs/alloc/logs"

    rm nomad/boilerplate-${_ticket}.nomad

    echo Deployment can be checked at ${url}
    echo Logs for this deployment can be found at ${log_url}
    echo Keep in mind that it may take a minute or two for your instance to be available and operational.
    exit 0
}

function print_ticket_subject {
    tix=$1

    tix_subject=$(curl -s -k \
        -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
        -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        -H 'Content-Type: application/json' \
        ${BLPT_REDMINE}/issues/${tix}.json \
        | jq --raw-output '.issue.subject')

    echo ${tix_subject}
}

function print_ticket_status {
    tix=$1

    tix_status=$(curl -s -k \
        -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
        -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        -H 'Content-Type: application/json' \
        ${BLPT_REDMINE}/issues/${tix}.json \
        | jq --raw-output '.issue.status.name')

    echo -n ${tix_status}
}

function print_blocked_tickets {
	tix=$1
	blockers=$(curl -sk \
		-H 'Content-Type: application/json' \
		-H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
		-H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
		${BLPT_REDMINE}/issues/${tix}/relations.json \
		| jq \
		  --raw-output \
		  '.relations | map(select(.relation_type == "blocks" and .issue_to_id == '$tix').issue_id) | join(",")')
}

function print_ticket_status_with_subject {
    tix=$1
    special=$2

    tix_status=$(curl -s -k \
        -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
        -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        -H 'Content-Type: application/json' \
        ${BLPT_REDMINE}/issues/${tix}.json \
        | jq --raw-output '.issue')

    status_id=$(echo ${tix_status} | jq --raw-output '.status.id')
    if [[ ${status_id} != ${status_deploy} ]]; then
	    export push_ok="N"
	    export push_bad="There are tickets in non-Deploy status"
    fi
    if [[ $special == 2 ]]; then
        if [[ ${status_id} != ${status_design_review} ]]; then
            _output=$(echo ${tix_status} | jq --raw-output '.status.name')${TAB_CHAR}❌${TAB_CHAR}$(echo ${tix_status} | jq --raw-output '.subject')
        else
            _output=$(echo ${tix_status} | jq --raw-output '.status.name')${TAB_CHAR}✅${TAB_CHAR}$(echo ${tix_status} | jq --raw-output '.subject')
        fi
    else
        _output=$(echo ${tix_status} | jq --raw-output '.status.name')${TAB_CHAR}$(echo ${tix_status} | jq --raw-output '.subject')
    fi
}

function push_unpushed_tickets {
    puphash=$1
    if [[ ${DEPLOY_CLI_NO_UPDATE_BACKEND} != "" ]];
    then
        echo "Skipping pushing unpushed tickets due to DEPLOY_CLI_NO_UPDATE_BACKEND"
    else
        unpushed_tickets=$(curl -s \
	    -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
	    -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
            ${DEPLOY_CLI_SERVICE}/tickets/unpushed/${puphash} \
            -H 'Content-Type: application/json' \
            -XGET \
            | jq -r 'map(.ticket) | join(" ")'
        )

        echo The following tickets were unpushed: ${unpushed_tickets}

        for upt in ${unpushed_tickets}; do
            echo Updating redmine to app_deployed for ${upt} / ${puphash}
            update_redmine "app_deployed" ${upt} ${puphash}
        done

        curl -s \
	    -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
	    -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
            ${DEPLOY_CLI_SERVICE}/tickets/push \
            -H 'Content-Type: application/json' \
            -XPOST \
            -d '{"tag": "'${puphash}'", "split": 1}'
    fi
}

function show_unpushed_tickets {
    sup_tickets=$(curl -s \
	-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
	-H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        ${DEPLOY_CLI_SERVICE}/tickets/unpushed \
        -H 'Content-Type: application/json' \
        -XGET \
        | jq -r 'map(.ticket) | join(" ")'
    )
    export push_ok="Y"
    staging_output="TICKET${TAB_CHAR}BLOCKERS${TAB_CHAR}STATUS${TAB_CHAR}SUBJECT####"
    for ticket in ${sup_tickets}
    do
	    print_blocked_tickets ${ticket}
    	    print_ticket_status_with_subject ${ticket}
	    if [[ ${blockers} == "" ]]; then
		    blockers="   "
	    else
		    export push_ok="N"
		    export push_bad="There are blocked tickets. Please manually review blockers to see if it's OK to push."
	    fi
	    staging_output="${staging_output}${ticket}${TAB_CHAR}${blockers}${TAB_CHAR}${_output}####"
    done
    echo ${staging_output} | sed 's/####/\n/g' | column -ts '###'

    if [[ ${push_ok} == "Y" ]]; then
        echo ""
	echo "✅ Current tag on Eng can be pushed to App"
    else
        echo ""
	echo "❌ Current tag on Eng cannot be pushed to App: ${push_bad}"
    fi
}

function show_tickets {
    _tag=$1

    st_tickets=$(curl -s \
        -H 'Content-Type: application/json' \
	-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
	-H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        -XGET ${DEPLOY_CLI_SERVICE}/tag/${_tag} \
        | jq -r '.tickets' 2>/dev/null)

    if [[ $? != 0 ]]
    then
        echo "Error: The provided tag does not seem to exist"
        exit 1
    fi

    echo The following tickets are part of this tag: ${st_tickets}

    for tix in ${st_tickets}; do
        tix_subject=$(curl -s -k \
            -H "X-Redmine-API-Key: ${BLPT_REDMINE_API_KEY}" \
	    -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
            -H 'Content-Type: application/json' \
            ${BLPT_REDMINE}/issues/${tix}.json \
            | jq --raw-output '.issue.subject')
        echo "- ${BLPT_REDMINE}/issues/${tix} => ${tix_subject}"
    done
}

function get_signed_for_app {
    _gsa_tag=$1
    curl -s \
        --fail \
        -H 'Content-Type: application/json' \
        -XGET \
        -d '{"tag": "'${_gsa_tag}'"}' \
	-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
        ${DEPLOY_CLI_SERVICE}/sign >/dev/null

    if [[ $? == 0 ]];
    then
       signed_for_app="TRUE"
    fi
}

function show_latest_tags {
    curl -s \
	-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
	-H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        ${DEPLOY_CLI_SERVICE}/tags | \
        jq -r 'map("\(.tag) \(.tickets)") | join("\n")' \
    | (while read -r _ti; do
        tag=$(echo ${_ti} | cut -d' ' -f1)
        signed_for_app="FALSE"
        get_signed_for_app ${tag}
        echo "* ${tag} (Signed for App: ${signed_for_app})"
        for _tix in $(echo ${_ti} | cut -d' ' -f2-)
        do
            echo -n "    ${_tix} => "
            print_ticket_subject ${_tix}
        done
       done)
}

function show_latest_deployments {
    _slb_instance=$1

    if [[ $_slb_instance == ""  ]]
    then
        echo "Error: Please provide an instance name"
        echo ""
        echo "Example:"
        echo "  $0 latest eng"
        echo ""
        print_available_instances
        exit 1
    fi

    (echo "TAG USER TIMESTAMP";
    curl -s \
	-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
	-H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        ${DEPLOY_CLI_SERVICE}/deploys/${_slb_instance} | \
        jq -r 'map("\(.tag) \(.user) \(.deployed_at | todate)") | join("\n")') \
    | column -t -s' '
}

function sign_tag {
    tag=$1
    curl -s \
        --fail \
        -XPOST \
	-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
	-H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d '{"tag": "'${tag}'", "user": "'${BLPT_USERNAME}'"}' \
        ${DEPLOY_CLI_SERVICE}/sign

    if [[ $? == 0 ]]
    then
        update_slack "tag_signed" ${tag}
        exit 0
    fi
    exit 1
}

function create_tag {
    tag=$1
    _ub_tickets="${*:2}"
    _internal_update_backend "new_tag" ${tag} "" "${_ub_tickets}"

    if [[ $? == 0 ]]
    then
        exit 0
    fi
    echo "An error occured while creating this tag."
    exit 1
}

function dispatch_nomad {
    case ${1} in
        test)
            build_nomad_test $2
            ;;
        stop)
            stop_nomad_test $2
            ;;
    esac
}

function show_deploy_logs {
    type=$1
    task=$2

    webs_alloc_id=$(curl -s ${NOMAD_ADDR}/v1/allocations | \
        jq -r "map(select(.JobID == \"${task}\")) | map(select(.TaskGroup == \"webs\")) | sort_by(.CreateTime) | map(.ID) | .[-1]")
    echo Found Allocation ID: ${webs_alloc_id}


    curl -s \
        ${NOMAD_ADDR}/v1/client/fs/logs/${webs_alloc_id}\?task\=boilerplate\&type\=${type}\&plain\=true
}

function dispatch_logs {
    case ${1} in
        stdout)
            show_deploy_logs "stdout" $2
            ;;
        stderr)
            show_deploy_logs "stderr" $2
            ;;
    esac
}

function emergency_deploy {
    _tag=$1
    if [[ ${_tag} == "" ]]; then
        echo "Error: This command expects a tag to be passed as argument"
        exit 1
    fi

    # Check if the tag was signed
    curl -s \
        --fail \
        -H 'Content-Type: application/json' \
	-H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
        -XGET \
        -d '{"tag": "'${_tag}'"}' \
        ${DEPLOY_CLI_SERVICE}/sign
    if [[ $? != 0  ]]
    then
        echo "Error: Before running this command, you need to make sure that the tag exists on the backend and is signed:"
        echo ""
        echo "  ./deploy-cli.sh create ${_tag}"
        echo "  ./deploy-cli.sh sign ${_tag}"
        echo ""
        exit 1
    fi
    echo "Deploying tag ${_tag} to App as per emergency protocols..."
    export _DEPLOY_CLI_EMERGENCY=1
    deploy app ${_tag}
}

function do_grab_remote {
    tag=$1
    aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 418430805305.dkr.ecr.us-east-2.amazonaws.com
    docker pull 418430805305.dkr.ecr.us-east-2.amazonaws.com/${tag}
    docker tag 418430805305.dkr.ecr.us-east-2.amazonaws.com/${tag} ${tag}
}

function post_ci {
    ticket=$1
    current_branch=$(git branch --show-current)
    # echo "data to submit":
    echo '{"build_type": "nomad", "ci_user": "'${BLPT_USERNAME}'", "branch": "'${current_branch}'", "tickets": "'${ticket}'"}'
    curl \
        --fail \
        -XPOST \
        -d '{"build_type": "nomad", "ci_user": "'${BLPT_USERNAME}'", "branch": "'${current_branch}'", "tickets": "'${ticket}'"}' \
        -H 'Content-Type: application/json' \
        -H "X-Boilerplate-Deploy-Key: ${BLPT_DEPLOY_KEY}" \
        -H "X-Boilerplate-API-Key: ${BLPT_API_KEY}" \
        ${DEPLOY_CLI_SERVICE}/ci

    echo " , submitted to the CI"
}

# Grab the config, if exists.
if [[ -e .deploy-cli.cfg  ]]
then
    source .deploy-cli.cfg
fi

check_dependencies

# Parse arguments
check_config_do_exit=1
case ${1} in
    --help|-h|-?)
	check_config_do_exit=0
        usage
        ;;
    login)
        login
        ;;
    list)
        check_config
        list
        ;;
    status)
        check_config
        node_status
        ;;
    build)
        check_config
        build_start "${*:2}"
        ;;
    deploy)
        check_config
        deploy $2 $3
        ;;
    deploy-remote)
        check_config
        do_grab_remote $3
        deploy $2 $3
        ;;
    stop)
        check_config
        stop_redmine $2
        ;;
    sign)
        check_config
        sign_tag $2
        ;;
    create)
        check_config
        create_tag $2
        ;;
    tickets)
        check_config
        show_tickets $2
        ;;
    tags)
        check_config
        show_latest_tags
        ;;
    latest)
        check_config
        show_latest_deployments $2
        ;;
    revert)
        echo "Error: This command is not implemented yet"
        exit 1
        ;;
    staging)
        check_config
        show_unpushed_tickets
        ;;
    nomad)
        check_config
        dispatch_nomad $2 $3
        ;;
    logs)
        check_config
        dispatch_logs $2 $3
        ;;
    emergency)
        check_config
        emergency_deploy $2
        ;;
    grab-remote)
        check_config
        do_grab_remote $2
        ;;
    ci)
        check_config
        post_ci $2
        ;;
    shiplogs)
        check_config
        ship_logs $2
        ;;
    (+([0-9]))
        check_config
        build_redmine $1
        ;;
    *)
	check_config_do_exit=0
        usage
        exit 2
        ;;
esac
