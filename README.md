# neoload-as-code
A set of workshop examples for running load tests based on code and from CLI contexts

**For Mac**:
```
git clone https://github.com/paulsbruce/neoload-as-code.git
cd neoload-as-code
chmod +x neoload-cli.sh
./neoload-cli.sh
```
**For Windows**:
```
git clone https://github.com/paulsbruce/neoload-as-code.git
cd neoload-as-code
neoload-cli.bat
```

This command is meant to be called with one of the following patterns:
    ```--verify```
      ↳ runs pre-checks and downloads necessary base images, does not run a NeoLoad test
    ```--init [replace_with_your_own_neoload_web_token]```
      ↳ runs a NeoLoad test for end-to-end basic system readiness; requires an API token
      ↳ obtain your token by following the instructions at [https://www.neotys.com/as-code](https://www.neotys.com/as-code
)
    ```--scenario=sanityScenario --file=projects/example_1_1_request/project.yaml```
       ↳ runs whatever load testing scenario you define in a project file; can be YAML or NLP

If you would like to follow along with the Getting Started guide, you can do so
by visiting: [neotys.com/as-code](https://www.neotys.com/as-code)
