# NeoLoad as-code Training, Module 1: Running Your First as-code Test

## Assumptions
```
cd ~/Desktop/neoload-as-code/training

# remember your connection details to NeoLoad Web, maybe add to ~/.bash_profile
export NLW_TOKEN=98c263bfof83b86b…
export NLW_URL=http://nlweb.shared:8080/

# connect to NeoLoad Web and use simple infrastructure spec
neoload login --url $NLW_URL $NLW_TOKEN
neoload test-settings --scenario sanityScenario create NewTest1
neoload project --path ./module1 upload
neoload run
```
