def call(Map params) {
  pipeline {
    agent none

    environment {
      docker_label="nljenkinsagent"
      nlw_host="nlweb.shared"
      nlw_api_url="http://${env.nlw_host}:8080"
      zone_id="defaultzone"
      full_test_max_vus = 5
      full_test_duration_mins = 3
      reporting_timespan = '10%-90%'
      API_URL = params.get('api_url')
      RESPONSE_CONTAINS = params.get('response_contains')
      CONCURRENCY_VUS = params.get('concurrency_vus')
      DURATION_MINS = params.get('duration_min')
    }

    stages {

      stage ('Validate parameters') {

        script {

          if(isNullOrEmpty(env.API_URL))
            error "You must specify a proper API URL."

          if(isNullOrEmpty(env.RESPONSE_CONTAINS))
            error "You must specify something that always describes successful response contents."

          if(env.CONCURRENCY_VUS.toInteger() > 100)
            error "You cannot run more than 100 concurrency threads (VUs) with this type of pipeline."

          if(env.DURATION_MINS.toInteger() > 60)
            error "You cannot run longer than 60mins with this type of pipeline."

        }
      }

      stage ('Prep workspace') {
        agent any
        steps {
          cleanWs()
          script {
            sh "uname -a"
            env.host_ip = sh(script: "getent hosts ${env.nlw_host} | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'", returnStdout: true)
            env.agent_name = "${env.VM_HOST_EXT_IP}" // sh(script: "uname -a | tr -s ' ' | cut -d ' ' -f2", returnStdout: true)
          }
        }
      }
      stage('Attach Worker') {
        agent {
          docker {
            image "${env.docker_label}:latest"
            args "--add-host ${env.nlw_host}:${env.host_ip} -e HOME=${env.WORKSPACE} -e PYTHONUNBUFFERED=1"
          }
        }




        stages {
          stage('Prepare agent') {
            steps {
              sh 'neoload --version'
              //sh 'printenv'
              withCredentials([string(credentialsId: 'NLW_TOKEN', variable: 'NLW_TOKEN')]) {
                sh "neoload login --url ${env.nlw_api_url} $NLW_TOKEN"
              }
            }
          }
          stage('Prepare Neoload CLI') {
            steps {
              sh "neoload test-settings --zone ${env.zone_id} --lgs 1 --scenario sanityScenario createorpatch 'example-Jenkins-module6d-${env.agent_name}'"
            }
          }
          stage('Prepare Test Assets') {
            steps {
              sh 'mkdir -p PVS/'
              dir("PVS") {
                git url: "https://github.com/Neotys-Connect/neoload-as-code.git"
              }
              sh 'rm -rf nl_project/ && mkdir -p nl_project/'
              sh 'cp PVS/training/module6/d/sanity.slas.nl.yaml nl_project/sanity.slas.nl.yaml'
              sh 'cp PVS/training/module6/d/templates/api.template.nl.yaml nl_project/default.yaml'
              script {
                yaml = readFile('nl_project/default.yaml')
                ['API_URL','RESPONSE_CONTAINS','CONCURRENCY_VUS','DURATION_MINS'].each { token ->
                  val = sh(script: "echo \$${token}", returnStdout: true).trim()
                  yaml = yaml.replace("[[${token}]]",val)
                }
                writeFile(file: 'nl_project/default.yaml', text: yaml)
              }
              sh 'cat nl_project/default.yaml'
              sh 'neoload validate nl_project/'
            }
          }
          stage('Upload Test Assets') {
            steps {
              sh "neoload project --path nl_project/ upload"
              sh "neoload status"
            }
          }

          // stage('Queue for available infra') {
          //   steps {
          //     // max period of time to queue = 5m
          //     // loop while max waiting period hasn't elapsed
          //     //    check for 'appropriate' zone --> neoload zones | jq '...'
          //     //    if found a zone, break --> continue
          //     //    if didn't find a zone, wait for short time, then check again
          //   }
          // }


          stage('Run a sanity scenario') {
            steps {
              script {
                sanityCode = 3 // default to something absurd
                try {
                  wrap([$class: 'BuildUser']) {
                    sanityCode = sh(script: """neoload run \
                          --scenario sanityScenario \
                          --name \"sanity-${env.JOB_NAME}-${env.BUILD_NUMBER}-${env.agent_name}\" \
                          --description \"Started by Jenkins user $BUILD_USER on ${env.agent_name}\" \
                          --as-code default.yaml,sanity.slas.nl.yaml \
                          """, returnStatus: true)
                  }
                } catch(error) {
                  error "Sanity test kickoff error ${error}"
                } finally {
                  print "Sanity status code was ${sanityCode}"
                  if(sanityCode > 0)
                    error "Sanity test failed so not proceeding to full test!"
                  else
                    sh "neoload test-results delete cur" // get rid of successful sanity run results
                    sleep(time:45,unit:"SECONDS")
                }
              }
            }
          }


          stage('Run Test') {
            stages {
              stage('Kick off test async') {
                steps {
                  wrap([$class: 'BuildUser']) {
                    sh """neoload run \
                      --scenario fullTest \
                      --name \"fullTest-${env.JOB_NAME}-${env.BUILD_NUMBER}-${env.agent_name}\" \
                      --description \"Started by Jenkins user $BUILD_USER on ${env.agent_name}\" \
                      --detached \
                      --as-code default.yaml
                    """
                  }
                }
              }
              stage('Monitor test') {
                parallel {
                  stage('Monitor SLAs') {
                    steps {
                      script {
                        logs_url = sh(script: "neoload logs-url cur", returnStdout: true).trim()
                        echo "Logs url: ${logs_url}"
                        sh "neoload fastfail --max-failure 25 slas cur"
                        //sh "neoload fastfail --max-failure 25 --stop-command './kill_script.sh' slas cur"
                      }
                    }
                  }
                  stage('Wait for test finale') {
                    steps {
                      script {
                        env.exitCode = sh(script: "neoload wait cur", returnStatus: true)
                        print "Final status code was ${env.exitCode}"
                      }
                      sh "mkdir -p nl_reports"
                      script {
                        sh """neoload report --filter='timespan=${env.reporting_timespan}' \
                              --out-file nl_reports/neoload-single-data.json \
                              cur
                          """

                        sh """neoload report \
                              --json-in nl_reports/neoload-single-data.json \
                              --template builtin:transactions-csv \
                              --out-file nl_reports/neoload-transactions.csv \
                              cur
                          """

                        sh """neoload report \
                              --json-in nl_reports/neoload-single-data.json \
                              --template reporting/jinja/sample-custom-report.html.j2 \
                              --out-file nl_reports/neoload-results.html \
                              cur
                          """
                        publishHTML (target: [
                            allowMissing: false,
                            alwaysLinkToLastBuild: false,
                            keepAll: true,
                            reportDir: 'nl_reports',
                            reportFiles: 'neoload-results.html',
                            reportName: "NeoLoad Test Results"
                        ])

                        sh """neoload report --filter='timespan=${env.reporting_timespan};results=-5' \
                              --out-file nl_reports/neoload-trend-data.json \
                              --type trends \
                              cur
                          """
                        sh """neoload report \
                              --json-in nl_reports/neoload-trend-data.json \
                              --template reporting/jinja/sample-trends-report.html.j2 \
                              --out-file nl_reports/neoload-trends.html \
                              --type trends \
                              cur
                          """
                        publishHTML (target: [
                            allowMissing: false,
                            alwaysLinkToLastBuild: false,
                            keepAll: true,
                            reportDir: 'nl_reports',
                            reportFiles: 'neoload-trends.html',
                            reportName: "NeoLoad Trends (Custom)"
                          ])
                      }
                    }
                  }
                } //end parallel
              }
            } // end stages
            post {
              always {
                sh "neoload test-results junitsla"
                junit testResults: 'junit-sla.xml', allowEmptyResults: true
                archiveArtifacts artifacts: 'nl_reports/*.*'
              }
            }
          }
        }
      }
    }
  }

}

def isNullOrEmpty(val) {
  return ("null".equals(val) || !val?.trim())
}
