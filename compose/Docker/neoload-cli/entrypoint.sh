#!/bin/sh

## first, let's prime the system with the latest NeoLoad binaries/images
##docker pull neotys/neoload-controller:latest
#docker pull paulsbruce/neoload-as-code-controller:latest

#echo 'inside the cli'

CTRL_CONTAINER_NAME=neoload-cli-ctrl
NL_CONTROLLER_DOCKER_IMAGENAME="paulsbruce/neoload-as-code-controller:6-10-c"

sleep 10

BASE_DIR=/neoload-as-code
#echo "entrypoint[BASE_DIR_HOST]: $BASE_DIR_HOST"
if [ -z "$BASE_DIR_HOST" ]; then
	echo "No BASE_DIR_HOST defined. Scraping it from docker inspect [BASE_DIR: $BASE_DIR]"
	BASE_DIR_HOST=$(docker inspect --format "{{ range .Mounts }}{{ if eq .Destination \"$BASE_DIR\" }}{{ .Source }}{{ end }}{{ end }}" $(docker ps -a -q --filter "name=neoload-cli" --filter "status=running" --format="{{.ID}}"))
fi

if echo "$BASE_DIR_HOST" | grep -q ":"; then
	# this is a windows machine :( and the paths must be translated :O
	# https://github.com/docker/toolbox/issues/607#issuecomment-301359751
	echo "Replacing windows path with Docker Desktop compliant string"
	COLON=":"
	BKSL="\\"
	FWSL="/"
	BASE_DIR_HOST=${BASE_DIR_HOST//$COLON/} #c\Users\username\neoload-as-code
	BASE_DIR_HOST=${BASE_DIR_HOST//$BKSL/$FWSL} #c/Users/username/neoload-as-code
	BASE_DIR_HOST=/$BASE_DIR_HOST #/c/Users/username/neoload-as-code
fi

LOGS_DIR_HOST=$BASE_DIR_HOST/.logs
LOGS_DIR=$BASE_DIR/.logs
BASE_DIR_HOST_CLI=$BASE_DIR_HOST/compose/Docker/neoload-cli
#docker network ls
CONF_VARS_DIR_NAME=.conf
CONF_VARS_DIR=$BASE_DIR/$CONF_VARS_DIR_NAME
CONF_VARS_FILEPATH=$CONF_VARS_DIR/docker-cli.custom.env
CONF_VARS_DIR_HOST=$BASE_DIR_HOST/$CONF_VARS_DIR_NAME

#echo "CLI Being Listing config dir"
#ls -latr $CONF_VARS_DIR
#echo "CLI End Listing config dir"

init_conf_file() {
  if [ ! -d "$CONF_VARS_DIR" ]; then
		echo "making CONF_VARS_DIR: $CONF_VARS_DIR"
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

# LOADS NLW_TOKEN INTO THIS SHELL CONTEXT
if [ -f "$CONF_VARS_FILEPATH" ]; then
  while IFS= read -r line
  do
    eval $line
  done < "$CONF_VARS_FILEPATH"
fi

#echo "NLW_TOKEN[0]: $NLW_TOKEN"

if [ -z "$NLW_TOKEN" ]; then # empty
    echo "examples:

    Congrats! You’ve initialized the NeoLoad As-Code Getting Started Guide! The next step is to connect to NeoLoad Web so you can visualize test results and run real-world load tests.

    If you already have an on-premise version of NeoLoad, you can skip the next section and simply type: docker-compose --file [EP_DOCKER_URL] -e NLW_URL=[Your NLW URL here] -e TOKEN=[your token here]

    /examples"

		exit 0
fi

#printenv

#echo "BASE_DIR_HOST: $BASE_DIR_HOST"
#echo "BASE_DIR: $BASE_DIR"
#echo "CONF_VARS_DIR_HOST: $CONF_VARS_DIR_HOST"
#echo "CONF_VARS_DIR: $CONF_VARS_DIR"


#CTRL_PROJECT_HOME=/home/neoload/neoload/neoload_project
CTRL_PROJECT_HOME=/home/neoload/.neotys/neoload/v6.10
#echo "NEEDS_SYSTEM_CHECK[0]: $NEEDS_SYSTEM_CHECK"

if [ $NEEDS_SYSTEM_CHECK = 1 ]; then
  echo "Since you've changed your NeoLoad Web token, a basic check to make sure it works is in order."
  #cp $BASE_DIR/compose/Docker/neoload-cli/nl_system_check.yaml $CONF_VARS_DIR
  echo "
mkdir -p $CTRL_PROJECT_HOME
cp $BASE_DIR/compose/Docker/neoload-cli/nl_system_check.yaml $CTRL_PROJECT_HOME
cd $CTRL_PROJECT_HOME && /home/neoload/neoload/bin/NeoLoadCmd -project $CTRL_PROJECT_HOME/nl_system_check.yaml -launch systemCheck -exit -noGUI -nlweb -nlwebToken ${NLW_TOKEN}
" > $CONF_VARS_DIR/current-controller-entrypoint.sh
#echo "CLI[writing to $CONF_VARS_DIR/current-controller-entrypoint.sh]"
#ls -latr $BASE_DIR
#ls -latr $CONF_VARS_DIR
ls -latr $CONF_vARS_DIR
	docker run --name neoload_ctrl --rm \
				-v "$BASE_DIR_HOST":"$BASE_DIR" \
				-v "$CONF_VARS_DIR_HOST":"$CONF_VARS_DIR" \
				--entrypoint "/bin/sh" $NL_CONTROLLER_DOCKER_IMAGENAME \
				$CONF_VARS_DIR/current-controller-entrypoint.sh
else
  if [ -z "$YAML_FILEPATH" ]; then # we're in init phase
    docker pull --quiet $NL_CONTROLLER_DOCKER_IMAGENAME
  fi
fi

pid=0
ret=3

#echo "YAML_FILEPATH[0]: $YAML_FILEPATH"
if [ ! -z "$YAML_FILEPATH" ]; then # not empty
    YAML_DIR=$(dirname "$YAML_FILEPATH")
    YAML_BASE_DIR_HOST=${YAML_DIR/$BASE_DIR/$BASE_DIR_HOST}
    YAML_NAME=$(basename "$YAML_FILEPATH")
    SCENARIO_NAME=$SCENARIO
		#echo "YAML_NAME[0]: $YAML_NAME"
    HOST_IP=$(dig +short host.docker.internal | grep '^[.0-9]*$')
    ADD_HOST_DOCKER_INTERNAL=
    if [ -z "$HOST_IP" ]; then
	    #echo 'ip route from cli'
	    #ip route show
      HOST_IP=$(ip route show | awk '/default/ {print $3}')
      HOST_IP="172.17.0.1" # hack until lookup is moved into controller container, instead of cli container (has 172.18.0.1)
      ADD_HOST_DOCKER_INTERNAL=" --add-host host.docker.internal:$HOST_IP "
      #echo "ADD_HOST_DOCKER_INTERNAL: [$ADD_HOST_DOCKER_INTERNAL]"
    fi
		if [ -f "$LOGS_DIR/neoload-out.log" ]; then
			rm -f "$LOGS_DIR/neoload-out.log"
			sleep 2
	  fi
		if [ -f "$CONF_VARS_DIR/current-controller-entrypoint.sh" ]; then
			rm -f "$CONF_VARS_DIR/current-controller-entrypoint.sh"
			sleep 2
	  fi

	echo "
	cp -R /src_project/** $CTRL_PROJECT_HOME
	cp /home/neoload/neoload/bin/NeoLoadCmd.vmoptions /home/neoload/.neotys/neoload/v6.10/logs/NeoLoadCmd.vmoptions
	#IF USING NLW FOR LICENSE#exec /home/neoload/neoload/bin/NeoLoadCmd -project $CTRL_PROJECT_HOME/$YAML_NAME -launch $SCENARIO_NAME -exit -noGUI -nlweb -nlwebToken ${NLW_TOKEN} -leaseServer nlweb -leaseLicense 50:1
	cd $CTRL_PROJECT_HOME && /home/neoload/neoload/bin/NeoLoadCmd -project $CTRL_PROJECT_HOME/$YAML_NAME -launch $SCENARIO_NAME -exit -noGUI -nlweb -nlwebToken ${NLW_TOKEN}
" > $CONF_VARS_DIR/current-controller-entrypoint.sh
		#echo "CLI[writing to $CONF_VARS_DIR/current-controller-entrypoint.sh]"
		#ls -latr $BASE_DIR
		#ls -latr $CONF_VARS_DIR
    sleep 2 # for above file to be written out

    # setup handlers
    # on callback, kill the last background process, which is `tail -f /dev/null` and execute the specified handler
    #echo "trapping SIGTERM"
    trap 'kill ${!}; my_handler' SIGUSR1
    trap 'kill ${!}; term_handler' SIGTERM
    # run application

    #echo "running neoload-ctrl container / engine"
    docker ps --format '{{.Names}}' | grep "^$CTRL_CONTAINER_NAME" | awk '{print $1}' | xargs -I {} docker kill {}
    # use paulsbruce/neoload-as-code-controller which comes with a tiny demo license
    #docker run --name $CTRL_CONTAINER_NAME --rm --cpus=".75" --memory-reservation 768M -v $BASE_DIR_HOST/$CONF_VARS_DIR_NAME:/$CONF_VARS_DIR_NAME -v "$YAML_DIR":/src_project --add-host localhost:$HOST_IP --entrypoint "/bin/sh" paulsbruce/neoload-as-code-controller /$CONF_VARS_DIR_NAME/current-controller-entrypoint.sh &
    #echo "using docker image: $NL_CONTROLLER_DOCKER_IMAGENAME"
    #echo "YAML_DIR: $YAML_DIR"
    #echo "YAML_NAME: $YAML_NAME"
    #echo "YAML_BASE_DIR_HOST: $YAML_BASE_DIR_HOST"
    #echo "BASE_DIR: $BASE_DIR"
    #echo "BASE_DIR_HOST: $BASE_DIR_HOST"
    ABS_YAML_BASE_DIR_HOST=${YAML_BASE_DIR_HOST//\/neoload-as-code\//}
    ABS_YAML_BASE_DIR_HOST=$BASE_DIR_HOST/$ABS_YAML_BASE_DIR_HOST
    echo "ABS_YAML_BASE_DIR_HOST: $ABS_YAML_BASE_DIR_HOST"
    docker run --name $CTRL_CONTAINER_NAME \
              --rm --cpus=".75" \
              --memory-reservation 768M \
              -v "$BASE_DIR_HOST":"$BASE_DIR" \
	      -v "$CONF_VARS_DIR_HOST":"$CONF_VARS_DIR" \
	      -v "$ABS_YAML_BASE_DIR_HOST":"/src_project/" \
              --add-host localhost:$HOST_IP \
              $ADD_HOST_DOCKER_INTERNAL \
              -e CONTROLLER_XMX=-Xmx768m \
              --entrypoint "/bin/sh" $NL_CONTROLLER_DOCKER_IMAGENAME \
              $CONF_VARS_DIR/current-controller-entrypoint.sh &
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
