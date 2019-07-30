#!/bin/sh

VERIFY=false
INIT=false
TOKEN=
SCENARIO=
FILE=
SPINUP_SAMPLE_TARGETS=true

cleanup() {
  docker stop $(docker ps -a --filter "name=neotys-examples" --format="{{.ID}}") > /dev/null 2>&1
  docker rm $(docker stop $(docker ps -a --filter "name=neoload-as-code" --format="{{.ID}}")) > /dev/null 2>&1
  docker rmi $(docker images -f="dangling=true" --format="{{.ID}}") > /dev/null 2>&1
}
bail() {
  cleanup
  EXIT_CODE=$1
  exit $EXIT_CODE
}
ALL_PARAMS="$@"
if [ -z "$ALL_PARAMS" ]; then
  echo "
Welcome! You have started the NeoLoad As-Code examples without the proper command line arguments.

This command is meant to be called with one of the following patterns:
    --verify
      ↳ runs pre-checks and downloads necessary base images, does not run a NeoLoad test
    --init [replace_with_your_own_neoload_web_token]
      ↳ runs a NeoLoad test for end-to-end basic system readiness; requires an API token
      ↳ obtain your token by following the instructions at https://www.neotys.com/as-code
    --scenario=sanityScenario --file=projects/example_1_1_request/project.yaml
       ↳ runs whatever load testing scenario you define in a project file; can be YAML or NLP

If you would like to follow along with the Getting Started guide, you can do so
by visiting: neotys.com/as-code
  "
  bail 5500
fi

for i in "$@"
do
case $i in
    -i=*|--init=*|--init|-i)
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

BASE_DIR=/neoload-as-code
if [ -z "$BASE_DIR_HOST" ]; then
  echo "getting BASE_DIR_HOST from inspect"
	BASE_DIR_HOST=$(docker inspect --format "{{ range .Mounts }}{{ if eq .Destination \"$BASE_DIR\" }}{{ .Source }}{{ end }}{{ end }}" $(docker ps -a -q --filter "name=neotys-examples-cli-params" --filter "status=running" --format="{{.ID}}"))
  echo "BASE_DIR_HOST: $BASE_DIR_HOST"
fi
if [ "$BASE_DIR_HOST" == "./" ]; then
  BASE_DIR_HOST=$(pwd)
  echo "BASE_DIR_HOST[pwd]: $BASE_DIR_HOST"
fi

CLI_BUILT=false
build_the_cli() {
  if ! $CLI_BUILT; then
    #docker-compose --file $BASE_DIR/examples.yaml --log-level ERROR build neoload-cli
    CLI_BUILT=true
  fi
}

#echo "\$\@: $@"
#echo "VERIFY: $VERIFY"
#echo "INIT: $INIT"
#echo "TOKEN: $TOKEN"
#echo "FILE: $FILE"
#echo "SCENARIO: $SCENARIO"

if $VERIFY ; then
  build_the_cli
  BASE_DIR_HOST=$BASE_DIR_HOST docker-compose --file $BASE_DIR/examples.yaml --log-level ERROR run neoload-cli
else
  if $INIT ; then
    if [ -z "$TOKEN" ]; then
      echo "Please provide your API token"
      bail 5501
    fi
    #if [ ! $TOKEN =~ [^a-zA-Z0-9\ ] ]; then
    len=$(expr "x$TOKEN" : "x[a-zA-Z0-9 ]*$")  ## test returns length if $1 all digits
    let len=len-1                   ## subtract 1 to compensate for 'x'

    if ! [ $len -gt 0 ]; then
      echo "Please provide your actual API token, be careful not to just copy-n-paste commands :)"
      bail 5502
    fi
    echo "initing..."
    build_the_cli
    #ls -latr $BASE_DIR
    BASE_DIR_HOST=$BASE_DIR_HOST NLW_TOKEN=$TOKEN docker-compose --file $BASE_DIR/$COMPOSE_YAML_FILE --log-level INFO run neoload-cli
  else

    if [[ ! -z "$SCENARIO" && ! -z "$FILE" ]]; then # not empty
      FILE=$BASE_DIR/$FILE
      FILEPATH="$( cd "${FILE%/*}" && pwd )"/"${FILE##*/}"

      #echo "params Being Listing config dir"
      #ls -latr $BASE_DIR/.conf
      #echo "params End Listing config dir"

      build_the_cli
      BASE_DIR_HOST=$BASE_DIR_HOST YAML=$FILEPATH SCN=$SCENARIO docker-compose --file $BASE_DIR/$COMPOSE_YAML_FILE --log-level WARNING run neoload-cli &
      COMPID=$!

      sleep 10

      while true; do
        # if neoload-cli container closed, move on ".org", ".net" > dr.evil
        clipsout=$(docker ps --format '{{.Names}}' | grep "neoload-cli" | awk '{print $1}')
        if [ -z "$clipsout" ]; then
          break
        fi
        sleep 2
      done

      echo "killing other $CONTAINERS_PREFIX containers"
      docker ps --format '{{.Names}}' | grep "^$CONTAINERS_PREFIX" | awk '{print $1}' | xargs -I {} docker kill {}

      wait $COMPID
    else
      echo "--file and --scenario parameters must be passed to run a test"
      bail 5503
    fi
  fi
fi

# on the unlikely event that things were successful (no bails), cleanup anyway
cleanup
