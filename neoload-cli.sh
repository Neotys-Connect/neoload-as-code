#!/bin/bash
### Purpose: curate the process of running NeoLoad As-Code getting started samples
### Documentation: https://github.com/paulsbruce/neoload-as-code
### Usage (assumes Docker is running locally):
### Step 1  $  neoload-cli.sh  --verify
### Step 2  $  neoload-cli.sh  --init [replace_with_your_own_neoload_web_token]
### Step 3  $  neoload-cli.sh  --scenario=sanityScenario --file=projects/example_1_1_request/project.yaml

BASE_DIR_HOST=.
LOGS_DIR_HOST=$BASE_DIR_HOST/.logs
NL_OUT_LOG_FILEPATH=$LOGS_DIR_HOST/neoload-out.log

# if doesn't already exist, create it for volume attach
mkdir -p $LOGS_DIR_HOST
rm -rf $LOGS_DIR_HOST/*




# for dev purposes
#docker-compose --file examples.yaml build --force-rm neotys-examples-cli-params
#docker-compose --file examples.yaml build --force-rm neoload-cli



BASE_DIR_HOST=$BASE_DIR_HOST/ NL_CLI_PARAMS=$* docker-compose --file examples.yaml --log-level ERROR run neotys-examples-cli-params &
COMPID=$!

sleep 10







URL_OPENED=false

while true; do

  # check for out log containing URL to NLW test, launch once if found
  if [ -f "$NL_OUT_LOG_FILEPATH" ]; then
    URL=$(grep -Eio 'http[s]?://.*/overview' $NL_OUT_LOG_FILEPATH)
    if [ ! -z "$URL" ] && ! $URL_OPENED; then
      URL_OPENED=true
      echo "opening URL"
      open $URL
    fi
  fi



  sleep 1

  # if neoload-cli container closed, move on ".org", ".net" > dr.evil
  clipsout=$(docker ps --format '{{.Names}}' | grep "neoload-cli" | awk '{print $1}')
  if [ -z "$clipsout" ]; then
    break
  fi

done

echo "waiting for docker-compose to exit"
wait $COMPID




















echo "CLI Exited"
