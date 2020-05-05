# NeoLoad as-code Training, Module 1: Running Your First as-code Test

## Connecting the CLI to the NeoLoad Web Platform
```
cd ~/Desktop/neoload-as-code/training

# remember your connection details to NeoLoad Web, maybe add to ~/.bash_profile
export NLW_TOKEN=98c263bfof83b86b…
export NLW_URL=http://nlweb.shared:8080/

# connect to NeoLoad Web and use simple infrastructure spec
neoload login --url $NLW_URL $NLW_TOKEN
```

## Explanation of each command
```
# create a new test's settings with dynamic names
neoload test-settings --scenario sanityScenario --naming-pattern \#\$\{runID\} create FirstTest_$RANDOM

# add project files to the test
neoload project --path ./module1 upload

# spin up a controller and load generator to act as BYO infrastructure
sudo neoload docker attach

# kick off the test
neoload run
```
NOTE: the 'sudo' command is only needed for docker BYO infrastructure AND when
the current user does not have permission to run native 'docker...' commands
