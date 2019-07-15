#!/bin/bash

#examples:
# chmod u+x neoload-cli.sh
# ./neoload-cli.sh --verify
# ./neoload-cli.sh --init [token]
# ./neoload-cli.sh --scenario=sanityScenario --file=projects/example_1_1_request/project.yaml

VERIFY=false
INIT=false
TOKEN=
SCENARIO=
FILE=
SPINUP_SAMPLE_TARGETS=true

for i in "$@"
do
case $i in
    -i=*|--init=*)
    INIT=true
    TOKEN="${i#*=}"
    shift # past argument=value
    ;;
    -s=*|--scenario=*)
    SCENARIO="${i#*=}"
    shift # past argument=value
    ;;
    -f=*|--file=*)
    FILE="${i#*=}"
    shift # past argument=value
    ;;
    -v|--verify)
    VERIFY=true
    shift # past argument with no value
    ;;
    *)
          # unknown option
    ;;
esac
done

COMPOSE_YAML_FILE=examples.yaml
CONTAINERS_PREFIX=neotys-examples-

if ! $SPINUP_SAMPLE_TARGETS ; then
  COMPOSE_YAML_FILE=
fi

LOGS_DIR_HOST=./.logs
NL_OUT_LOG_FILEPATH=$LOGS_DIR_HOST/neoload-out.log

build_the_cli() {
  docker pull paulsbruce/neoload-as-code-controller
  docker-compose --file examples.yaml --log-level ERROR build neoload-cli
}

# set positional arguments in their proper place
#eval set -- "$PARAMS"
if $VERIFY ; then
  build_the_cli
  docker-compose --file examples.yaml --log-level ERROR run neoload-cli
else
  if $INIT ; then
    echo "Init..."
    build_the_cli
    NLW_TOKEN=$TOKEN docker-compose --file $COMPOSE_YAML_FILE --log-level INFO run neoload-cli
  else
    if [[ ( ! -z "$SCENARIO" && ! -z "$FILE" ) ]]; then # not empty
      FILEPATH="$( cd "${FILE%/*}" && pwd )"/"${FILE##*/}"

      # if doesn't already exist, create it for volume attach
      mkdir -p $LOGS_DIR_HOST
      rm -rf $LOGS_DIR_HOST/*

      #echo "FILEPATH: $FILEPATH"
      #echo "SCENARIO: $SCENARIO"
      build_the_cli
      YAML=$FILEPATH SCN=$SCENARIO docker-compose --file $COMPOSE_YAML_FILE --log-level WARNING run neoload-cli &
      COMPID=$!

      #echo "testing docker ps"
      #docker ps --format '{{.Names}}' | grep "neoload-cli" | awk '{print $1}'
      #echo "now waiting for neoload-cli to exit"

      sleep 10

      URL_OPENED=false

      while true; do
        # if neoload-cli container closed, move on ".org", ".net" > dr.evil
        clipsout=$(docker ps --format '{{.Names}}' | grep "neoload-cli" | awk '{print $1}')
        if [ -z "$clipsout" ]; then
          break
        fi
        # check for out log containing URL to NLW test, launch once if found
        if [ -f "$NL_OUT_LOG_FILEPATH" ]; then
          URL=$(grep -Eio 'http[s]?://.*/overview' $NL_OUT_LOG_FILEPATH)
          if [ ! -z "$URL" ] && ! $URL_OPENED; then
            URL_OPENED=true
            echo "opening URL"
            open $URL
          fi
        fi
        sleep 2
      done

      echo "killing other $CONTAINERS_PREFIX containers"
      docker ps --format '{{.Names}}' | grep "^$CONTAINERS_PREFIX" | awk '{print $1}' | xargs -I {} docker kill {}

      echo "waiting for docker-compose to exit"
      wait $COMPID
    else
      echo "--file and --scenario parameters must be passed to run a test"
    fi
  fi
fi

docker stop $(docker ps -a --filter "name=neotys-examples" --format="{{.ID}}") > /dev/null 2>&1
docker rm $(docker stop $(docker ps -a --filter "name=neoload-as-code" --format="{{.ID}}")) > /dev/null 2>&1
docker rmi $(docker images -f="dangling=true" --format="{{.ID}}") > /dev/null 2>&1
