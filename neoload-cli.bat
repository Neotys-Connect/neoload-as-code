@echo off
REM Purpose: curate the process of running NeoLoad As-Code getting started samples
REM Documentation: https://github.com/paulsbruce/neoload-as-code
REM Usage (assumes Docker is running locally):
REM Step 1 :\> neoload-cli.bat --verify
REM Step 2 :\> neoload-cli.bat --init [token]
REM Step 3 :\> neoload-cli.bat --scenario=sanityScenario --file=projects/example_1_1_request/project.yaml

SET BASE_DIR_HOST=%cd%
SET LOGS_DIR_HOST=%BASE_DIR_HOST%\.logs
SET NL_OUT_LOG_FILEPATH=%LOGS_DIR_HOST%\neoload-out.log

REM if doesn't already exist, create it for volume attach
setlocal enableextensions enabledelayedexpansion
if not exist %LOGS_DIR_HOST% mkdir %LOGS_DIR_HOST%
del /f /q %LOGS_DIR_HOST%\*
endlocal

SET BASE_DIR_HOST=%BASE_DIR_HOST:\=/%
SET BASE_DIR_HOST=%BASE_DIR_HOST::=%
SET BASE_DIR_HOST=//%BASE_DIR_HOST%
SET BASE_DIR_HOST=%BASE_DIR_HOST:C=c%
SET BASE_DIR_HOST=%BASE_DIR_HOST:users=Users%

SET NL_CLI_PARAMS=%*
@start /b cmd /c docker-compose --file examples.yaml --log-level ERROR run neotys-examples-cli-params

powershell -noprofile -command "Start-Sleep -s 2"

set "PID="
for /f "tokens=2" %%A in ('tasklist ^| findstr /i "docker-compose" 2^>NUL') do @Set "PID=%%A"
if not defined PID (
	GOTO NotAttached
)

SET URL_OPENED=false

:WhileFile

  IF "%URL_OPENED%"=="false" (
	IF EXIST %NL_OUT_LOG_FILEPATH% (
   		SET URL=
    		for /F "delims=" %%a in ('findstr /b /r "http[s]://.*/overview" "%NL_OUT_LOG_FILEPATH%"') do (
			@Set "URL=%%a"
		)
    		if NOT "%URL%" == "" (
      			SET URL_OPENED=true
      			echo "opening URL: [%URL%]"
      			start "" %URL%
    		)
	)
	powershell -noprofile -command "Start-Sleep -s 1"

	qprocess %PID% >NUL 2>&1
	IF ERRORLEVEL 1 (
	  GOTO AfterCompose
	)
  )

  powershell -noprofile -command "Start-Sleep -s 1"

GOTO WhileFile

@echo on
echo "waiting for docker-compose to exit"
@echo off

:WhileCompose
qprocess %PID% >NUL 2>&1
IF ERRORLEVEL 1 (
  GOTO AfterCompose
) ELSE (
  REM ECHO Docker Compose is still running
  powershell -noprofile -command "Start-Sleep -s 1"
  GOTO WhileCompose
)

GOTO AfterCompose

:NotAttached
echo "Could not attach to Docker-Compose to verify that things are running smoothly"
GOTO AfterCompose

:AfterCompose

echo "CLI Exited"
