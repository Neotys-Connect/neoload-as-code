

REM examples:
REM neoload-cli.sh --verify
REM neoload-cli.sh --init [token]
REM neoload-cli.sh --scenario=sanityScenario --file=projects/example_1_1_request/project.yaml


SET LOGS_DIR_HOST=.\.logs
SET NL_OUT_LOG_FILEPATH=$LOGS_DIR_HOST\neoload-out.log

# if doesn't already exist, create it for volume attach
@echo off
setlocal enableextensions enabledelayedexpansion
mkdir -p $LOGS_DIR_HOST
rm -rf $LOGS_DIR_HOST/*
endlocal

# for dev purposes
#docker-compose --file examples.yaml build --force-rm neotys-examples-cli-params
#docker-compose --file examples.yaml build --force-rm neoload-cli
#docker-compose --file examples.yaml build --force-rm --no-cache geolookup && docker-compose --file examples.yaml run geolookup

NL_CLI_PARAMS=$@ docker-compose --file examples.yaml --log-level ERROR run neotys-examples-cli-params &
COMPID=$!

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

echo "waiting for docker-compose to exit"
wait $COMPID
