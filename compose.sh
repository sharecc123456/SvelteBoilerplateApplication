#!/bin/bash
#
shopt -s extglob

function usage {
    echo "Usage:"
    echo ""
    echo "Managing runtime"
    echo "  $0 up                  <-- Start docker-compose"
    echo "  $0 up --force-recreate <-- Start docker-compose (with forced recreation of all containers)"
    echo "  $0 down                <-- Stop docker-compose"
    echo "  $0 build               <-- Rebuild base-image"
    echo "  $0 build --no-cache    <-- Rebuild base-image without using any caches"
    echo "  $0 deps                <-- Fetch mix dependencies"
    echo ""
    echo "Managing the database"
    echo "  $0 newdb    <-- Clear the database"
    echo "  $0 migrate  <-- Execute migrations"
    echo ""
    echo "Managing Redis"
    echo "  $0 redisclear <-- Clear the recipient dashoard cache"
    exit 1
}

function do_up {
    docker-compose up ${*:2}
}

function do_down {
    docker-compose down ${*:2}
}

function do_build {
    docker-compose build ${*:2}
}

case ${1} in
    up)
        do_up ${*:1}
        ;;
    down)
        do_down ${*:1}
        ;;
    build)
        do_build ${*:1}
        ;;
    redisclear)
        redis-cli -h localhost -p 56379 --scan --pattern recipient-\* | xargs redis-cli del
        ;;
    newdb)
        docker-compose run web bash -c 'set -o allexport; source doppler.env; set +o allexport; mix ecto.reset'
        ;;
    migrate)
        docker-compose run web bash -c 'set -o allexport; source doppler.env; set +o allexport; mix ecto.migrate'
        ;;
    deps)
        docker-compose run web bash -c 'set -o allexport; source doppler.env; set +o allexport; mix deps.get'
        ;;
    *)
        usage
        ;;
esac
