#!/bin/sh

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

BASE_DIR=/neoload-as-code
BASE_DIR_HOST=$(docker inspect --format "{{ range .Mounts }}{{ if eq .Destination \"$BASE_DIR\" }}{{ .Source }}{{ end }}{{ end }}" $(docker ps -a -q --filter "name=neotys-examples-cli-params" --filter "status=running" --format="{{.ID}}"))

CLI_BUILT=false
build_the_cli() {
  if ! $CLI_BUILT; then
    #docker pull paulsbruce/neoload-as-code-controller
    #docker-compose --file $BASE_DIR/examples.yaml --log-level ERROR build neoload-cli
    CLI_BUILT=true
  fi
}

if $VERIFY ; then
  build_the_cli
  BASE_DIR_HOST=$BASE_DIR_HOST docker-compose --file $BASE_DIR/examples.yaml --log-level ERROR run neoload-cli
else
  if $INIT ; then
    if [ -z "$TOKEN" ]; then
      echo "Please provide your API token"
      exit -1
    fi
    #if [ ! $TOKEN =~ [^a-zA-Z0-9\ ] ]; then
    len=$(expr "x$TOKEN" : "x[a-zA-Z0-9 ]*$")  ## test returns length if $1 all digits
    let len=len-1                   ## subtract 1 to compensate for 'x'

    if ! [ $len -gt 0 ]; then
      echo "Please provide your actual API token, be careful not to just copy-n-paste commands :)"
      exit -2
    fi
    build_the_cli
    #ls -latr $BASE_DIR
    BASE_DIR_HOST=$BASE_DIR_HOST NLW_TOKEN=$TOKEN docker-compose --file $BASE_DIR/$COMPOSE_YAML_FILE --log-level INFO run neoload-cli
  else

    if [[ ! -z "$SCENARIO" && ! -z "$FILE" ]]; then # not empty
      FILE=$BASE_DIR/$FILE
      FILEPATH="$( cd "${FILE%/*}" && pwd )"/"${FILE##*/}"

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
    fi
  fi
fi

docker stop $(docker ps -a --filter "name=neotys-examples" --format="{{.ID}}") > /dev/null 2>&1
docker rm $(docker stop $(docker ps -a --filter "name=neoload-as-code" --format="{{.ID}}")) > /dev/null 2>&1
docker rmi $(docker images -f="dangling=true" --format="{{.ID}}") > /dev/null 2>&1
