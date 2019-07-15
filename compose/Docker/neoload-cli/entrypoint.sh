#!/bin/sh
#set -x

## first, let's prime the system with the latest NeoLoad binaries/images
##docker pull neotys/neoload-controller:latest
#docker pull paulsbruce/neoload-as-code-controller:latest

CTRL_CONTAINER_NAME=neoload-cli-ctrl
NL_CONTROLLER_DOCKER_IMAGENAME=paulsbruce/neoload-as-code-controller

BASE_DIR=/neoload-as-code
BASE_DIR_HOST=$(docker inspect --format "{{ range .Mounts }}{{ if eq .Destination \"$BASE_DIR\" }}{{ .Source }}{{ end }}{{ end }}" $(docker ps -a -q --filter "name=neoload-cli" --format="{{.ID}}"))
LOGS_DIR_HOST=$BASE_DIR_HOST/.logs
BASE_DIR_HOST_CLI=$BASE_DIR_HOST/compose/Docker/neoload-cli
#docker network ls
CONF_VARS_DIR_NAME=.conf
CONF_VARS_DIR=$BASE_DIR/$CONF_VARS_DIR_NAME
CONF_VARS_FILEPATH=$CONF_VARS_DIR/docker-cli.custom.env

init_conf_file() {
  if [ ! -d "$CONF_VARS_DIR" ]; then
    mkdir $CONF_VARS_DIR
  fi
  if [ ! -f "$CONF_VARS_FILEPATH" ]; then
    echo "creating '$CONF_VARS_FILEPATH'"
    echo "NLW_TOKEN=$NLW_TOKEN" > $CONF_VARS_FILEPATH
  fi
}

NEEDS_SYSTEM_CHECK=0

if [ ! -z "$NLW_TOKEN" ]; then # not empty
  NEEDS_SYSTEM_CHECK=1
  init_conf_file
  sed "/^NLW_TOKEN=/{h;s/=.*/=$NLW_TOKEN/};\${x;/^\$/{s//NLW_TOKEN=$NLW_TOKEN/;H};x}" $CONF_VARS_FILEPATH
fi

if [ -f "$CONF_VARS_FILEPATH" ]; then
  while IFS= read -r line
  do
    eval $line
  done < "$CONF_VARS_FILEPATH"
fi

if [ -z "$NLW_TOKEN" ]; then # empty
    echo "examples:

    Congrats! You’ve initialized the NeoLoad As-Code Getting Started Guide! The next step is to connect to NeoLoad Web so you can visualize test results and run real-world load tests.

    If you already have an on-premise version of NeoLoad, you can skip the next section and simply type: docker-compose --file [EP_DOCKER_URL] -e NLW_URL=[Your NLW URL here] -e TOKEN=[your token here]

    /examples"
fi

#printenv

#CTRL_PROJECT_HOME=/home/neoload/neoload/neoload_project
CTRL_PROJECT_HOME=/home/neoload/.neotys/neoload/v6.10

if [ $NEEDS_SYSTEM_CHECK = 1 ]; then
  cp $BASE_DIR/compose/Docker/neoload-cli/nl_system_check.yaml $CONF_VARS_DIR
  echo "
  mkdir -p $CTRL_PROJECT_HOME
cp /$CONF_VARS_DIR_NAME/nl_system_check.yaml $CTRL_PROJECT_HOME
cd $CTRL_PROJECT_HOME && /home/neoload/neoload/bin/NeoLoadCmd -project $CTRL_PROJECT_HOME/nl_system_check.yaml -launch systemCheck -exit -noGUI -nlweb -nlwebToken ${NLW_TOKEN}
" > $CONF_VARS_DIR/current-controller-entrypoint.sh
  docker run --name neoload_ctrl --rm -v $BASE_DIR_HOST/$CONF_VARS_DIR_NAME:/$CONF_VARS_DIR_NAME --entrypoint "/bin/sh" $NL_CONTROLLER_DOCKER_IMAGENAME /$CONF_VARS_DIR_NAME/current-controller-entrypoint.sh
fi

pid=0
ret=3

if [ ! -z "$YAML_FILEPATH" ]; then # not empty
    YAML_DIR=$(dirname "$YAML_FILEPATH")
    YAML_NAME=$(basename "$YAML_FILEPATH")
    SCENARIO_NAME=$SCENARIO
    HOST_IP=$(dig +short host.docker.internal | grep '^[.0-9]*$')
    echo "
cp -R /src_project/** $CTRL_PROJECT_HOME
cp /home/neoload/neoload/bin/NeoLoadCmd.vmoptions /home/neoload/.neotys/neoload/v6.10/logs/NeoLoadCmd.vmoptions
#IF USING NLW FOR LICENSE#exec /home/neoload/neoload/bin/NeoLoadCmd -project $CTRL_PROJECT_HOME/$YAML_NAME -launch $SCENARIO_NAME -exit -noGUI -nlweb -nlwebToken ${NLW_TOKEN} -leaseServer nlweb -leaseLicense 50:1
cd $CTRL_PROJECT_HOME && /home/neoload/neoload/bin/NeoLoadCmd -project $CTRL_PROJECT_HOME/$YAML_NAME -launch $SCENARIO_NAME -exit -noGUI -nlweb -nlwebToken ${NLW_TOKEN}
" > $CONF_VARS_DIR/current-controller-entrypoint.sh

    # setup handlers
    # on callback, kill the last background process, which is `tail -f /dev/null` and execute the specified handler
    #echo "trapping SIGTERM"
    trap 'kill ${!}; my_handler' SIGUSR1
    trap 'kill ${!}; term_handler' SIGTERM
    # run application

    echo "running neoload-ctrl container / engine"
    docker ps --format '{{.Names}}' | grep "^$CTRL_CONTAINER_NAME" | awk '{print $1}' | xargs -I {} docker kill {}
    # use paulsbruce/neoload-as-code-controller which comes with a tiny demo license
    #docker run --name $CTRL_CONTAINER_NAME --rm --cpus=".75" --memory-reservation 768M -v $BASE_DIR_HOST/$CONF_VARS_DIR_NAME:/$CONF_VARS_DIR_NAME -v "$YAML_DIR":/src_project --add-host localhost:$HOST_IP --entrypoint "/bin/sh" paulsbruce/neoload-as-code-controller /$CONF_VARS_DIR_NAME/current-controller-entrypoint.sh &
    docker run --name $CTRL_CONTAINER_NAME --rm --cpus=".75" --memory-reservation 768M -v $BASE_DIR_HOST/$CONF_VARS_DIR_NAME:/$CONF_VARS_DIR_NAME -v $LOGS_DIR_HOST:/home/neoload/.neotys/neoload/v6.10/logs -v "$YAML_DIR":/src_project --add-host localhost:$HOST_IP -e CONTROLLER_XMX=-Xmx768m --entrypoint "/bin/sh" $NL_CONTROLLER_DOCKER_IMAGENAME /$CONF_VARS_DIR_NAME/current-controller-entrypoint.sh &
    pid="$!"
    # wait forever
    while true
    do
      ps ax | grep $pid | grep -v grep > /dev/null
      ret=$?
      if test "$ret" != "0"
      then
          echo "NeoLoad Process Ended"
          break
      fi
      sleep 5

      #echo "tailing"
      #tail -f /dev/null & wait ${!}
    done

fi

# SIGUSR1-handler
my_handler() {
  echo
"my_handler"
}
# SIGTERM-handler
term_handler() {

if [ $pid -ne 0 ]; then

kill -SIGTERM "$pid"

wait "$pid"
  fi

exit 143; # 128 + 15 -- SIGTERM
}


exit $ret

#docker inspect neoload-cli
