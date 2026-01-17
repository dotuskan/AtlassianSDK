



@echo off
if "%OS%" == "Windows_NT" setlocal enableextensions enabledelayedexpansion



rem ---------------------------------------------------------------
rem Check for help command
rem ---------------------------------------------------------------

if /I "%1"=="help" goto showhelp
if /I "%1"=="-?" goto showhelp
if /I "%1"=="-h" goto showhelp
if /I "%1"=="-help" goto showhelp
if /I "%1"=="--help" goto showhelp
if /I "%1"=="/?" goto showhelp
if /I "%1"=="/h" goto showhelp
if /I "%1"=="/help" goto showhelp

goto continue

:showhelp
echo.
echo Usage: atlas-create-stash-plugin-module [options]
echo.
echo Creates a Stash Plugin Module
goto end

:continue

rem ---------------------------------------------------------------
rem Find absolute path to the program
rem ---------------------------------------------------------------

set PRGDIR=%~dp0
set CURRENTDIR=%cd%
cd /d %PRGDIR%..
set ATLAS_HOME=%cd%
cd /d %CURRENTDIR%


rem ---------------------------------------------------------------
rem Identify Maven location relative to script
rem ---------------------------------------------------------------

set M2_HOME=%ATLAS_HOME%\apache-maven-3.9.8
set MAVEN_EXECUTABLE="%M2_HOME%\bin\mvn.cmd"
set ATLAS_VERSION="9.1.1"
set AMPS_PLUGIN_VERSION="9.1.1"

if not "%ATLAS_MVN%"=="" set MAVEN_EXECUTABLE="%ATLAS_MVN%"


rem Check that the target executable exists

if not exist "!MAVEN_EXECUTABLE!" (
	echo Cannot find %MAVEN_EXECUTABLE%
	echo This file is needed to run this program
	goto end
)



rem ---------------------------------------------------------------
rem Transform Parameters into Maven Parameters
rem
rem NOTE: in DOS, all the 'else' statements must be on the same
rem line as the closing bracket for the 'if' statement.
rem ---------------------------------------------------------------

set ARGV=.%*
call :parse_argv
if ERRORLEVEL 1 (
  echo Cannot parse arguments
  endlocal
  exit /B 1
)

set MAVEN_OPTS=-Xms512M -Xmx768M %ATLAS_OPTS%
set MVN_PARAMS=-gs %M2_HOME%/conf/settings.xml

set isOld=0
    if exist pom.xml (
        echo [INFO] Project POM found
        set count=0
        echo [INFO] Resolving plugin info, may take a while on the first run.

        set errors=0
        for /F "tokens=* USEBACKQ" %%F in (`%MAVEN_EXECUTABLE% --batch-mode org.apache.maven.plugins:maven-dependency-plugin:3.1.2:resolve-plugins -DincludeGroupIds^=com.atlassian.maven.plugins -DexcludeTransitive^=true`) do (
            echo %%F
            set /a count=!count!+1
            set resolvedPlugins!count!=%%F
            echo "%%F" | findStr /c:"[ERROR]" >nul 2> nul
            if !errorLevel! equ 0 set errors=1
        )
        rem Errors in the config of the AMPS plugin will be identified by maven in this step, exit if errors are found
        if !errors! equ 1 Exit/B 0

        rem Find first matching resolved plugin
        set newPlugins=bamboo-maven-plugin bitbucket-maven-plugin confluence-maven-plugin crowd-maven-plugin fecru-maven-plugin jira-maven-plugin refapp-maven-plugin amps-maven-plugin
        set oldPlugins=maven-bamboo-plugin maven-confluence-plugin maven-crowd-plugin maven-fecru-plugin maven-jira-plugin maven-stash-plugin maven-refapp-plugin maven-amps-plugin
        set lineToParse=""
        for /L %%a in (1,1,!count!) do (
            for %%b in (%newPlugins%) do (
                if not defined foundPlugin (
                    echo "!resolvedPlugins%%a!" | findstr /ic:%%b >nul 2> nul
                    if !errorlevel! equ 0 (
                        set isOld=0
                        set lineToParse=!resolvedPlugins%%a!
                        set foundPlugin=%%b
                    )
                )
            )
            for %%b in (%oldPlugins%) do (
                if not defined foundPlugin (
                    echo "!resolvedPlugins%%a!" | findstr /ic:%%b >nul 2> nul
                    if !errorlevel! equ 0 (
                        set isOld=1
                        set lineToParse=!resolvedPlugins%%a!
                        set foundPlugin=%%b
                    )
                )
            )
        )

        for /F "tokens=4 delims=:" %%V in ("!lineToParse!") do set AMPS_PLUGIN_VERSION=%%V
        echo [INFO] Project defined AMPS version detected: !AMPS_PLUGIN_VERSION!
    )


set ARGI = 0

:loopstart
set /a ARGI = !ARGI! + 1
set /a ARGN = !ARGI! + 1

if !ARGI! gtr %ARGC% (
    goto loopend
)
call :getarg !ARGI! ARG
call :getarg !ARGN! ARGNEXT


if /I "%ARG%"=="--maven-plugin-version" (
    set AMPS_PLUGIN_VERSION=%ARGNEXT%
    set MVN_PARAMS=%MVN_PARAMS% -Damps.version=%ARGNEXT%
    set /a ARGI = !ARGI! + 1
    goto loopstart
)
if /I "%ARG%"=="-u" (
    set AMPS_PLUGIN_VERSION=%ARGNEXT%
    set MVN_PARAMS=%MVN_PARAMS% -Damps.version=%ARGNEXT%
    set /a ARGI = !ARGI! + 1
    goto loopstart
) 
set MVN_PARAMS=%MVN_PARAMS% %ARG%
goto loopstart

:loopend


set AMPS_PLUGIN_VERSION_STRIPPED=0
set AMPS_PLUGIN_VERSION_STRIPPED=%AMPS_PLUGIN_VERSION:"=%
set AMPS_PLUGIN_VERSION_STRIPPED=%AMPS_PLUGIN_VERSION_STRIPPED:'=%

if "%AMPS_PLUGIN_VERSION_STRIPPED%" LSS "8" (
    set MVN_PLUGIN=maven-stash-plugin
)
if "%AMPS_PLUGIN_VERSION_STRIPPED%" GEQ "8" (
    set MVN_PLUGIN=bitbucket-maven-plugin
)

set MVN_COMMAND=com.atlassian.maven.plugins:%MVN_PLUGIN%:%AMPS_PLUGIN_VERSION_STRIPPED%:create-plugin-module

rem ------------------------------------------------------------------------------------
rem Check for conflicts between Amps version and plugin artifact ID in plugin pom file
rem ------------------------------------------------------------------------------------

goto :skipPrintErrors
:printErrors
	echo [ERROR] Invalid Atlassian maven plugin(s) detected: %~1
	echo [ERROR] Please update your plugin POM to use the %~2
	echo [ERROR] See go.atlassian.com/atlassdk-147 for more information
Exit/B 0
:skipPrintErrors

    if exist pom.xml (
        set MOJO=create-stash-plugin-module
        set MOJO_MATCH=false
    )

if "%NEW_PLUGIN_ARTIFACT_ID%" NEQ "" ( set "NEW_PLUGIN_ARTIFACT_ID=%NEW_PLUGIN_ARTIFACT_ID:;=&echo.%" )
if "%OLD_PLUGIN_ARTIFACT_ID%" NEQ "" ( set "OLD_PLUGIN_ARTIFACT_ID=%OLD_PLUGIN_ARTIFACT_ID:;=&echo.%" )

if "%MOJO:~0,4%" EQU "run" (
	set MOJO_MATCH=true
)
if "%MOJO:~0,6%" EQU "debug" (
	set MOJO_MATCH=true
)
if "%MOJO:~-13%" EQU "plugin-module" (
	set MOJO_MATCH=true
)
if "%MOJO:~-16%" EQU "integration-test" (
	set MOJO_MATCH=true
)

    if exist pom.xml if "%MOJO_MATCH%" EQU "true" if %AMPS_PLUGIN_VERSION_STRIPPED% NEQ 0 (
        if %AMPS_PLUGIN_VERSION_STRIPPED% LSS 8 if isOld EQU 1 (
            call :printErrors "%NEW_PLUGIN_ARTIFACT_ID%" "old maven plugin name(s) for your product, or update to AMPS 8.0.0 or later"
            Exit/B 0
        )
        if %AMPS_PLUGIN_VERSION_STRIPPED% GEQ 8 if isOld EQU 0 (
            call :printErrors "%OLD_PLUGIN_ARTIFACT_ID%" "updated maven plugin name(s) for your product, or ensure you are using AMPS 6.x"
            Exit/B 0
        )
    )

rem ---------------------------------------------------------------
rem Executing Maven
rem ---------------------------------------------------------------

echo Executing: %MAVEN_EXECUTABLE% %MVN_COMMAND% %MVN_PARAMS%
%MAVEN_EXECUTABLE% %MVN_COMMAND% %MVN_PARAMS%

rem ---------------------------------------------------------------
rem (AMPS-197) The batch routines below for correct handling 
rem parameters containing of = and ; are from Skypher's excellent 
rem blog: 
rem http://skypher.com/index.php/2010/08/17/batch-command-line-arguments/
rem ---------------------------------------------------------------

:parse_argv
  SET PARSE_ARGV_ARG=[]
  SET PARSE_ARGV_END=FALSE
  SET PARSE_ARGV_INSIDE_QUOTES=FALSE
  SET /A ARGC = 0
  SET /A PARSE_ARGV_INDEX=1
  :PARSE_ARGV_LOOP
  CALL :PARSE_ARGV_CHAR !PARSE_ARGV_INDEX! "%%ARGV:~!PARSE_ARGV_INDEX!,1%%"
  IF ERRORLEVEL 1 (
    EXIT /B 1
  )
  IF !PARSE_ARGV_END! == TRUE (
    EXIT /B 0
  )
  SET /A PARSE_ARGV_INDEX=!PARSE_ARGV_INDEX! + 1
  GOTO :PARSE_ARGV_LOOP
 
  :PARSE_ARGV_CHAR
    IF ^%~2 == ^" (
      SET PARSE_ARGV_END=FALSE
      SET PARSE_ARGV_ARG=.%PARSE_ARGV_ARG:~1,-1%%~2.
      IF !PARSE_ARGV_INSIDE_QUOTES! == TRUE (
        SET PARSE_ARGV_INSIDE_QUOTES=FALSE
      ) ELSE (
        SET PARSE_ARGV_INSIDE_QUOTES=TRUE
      )
      EXIT /B 0
    )
    IF %2 == "" (
      IF !PARSE_ARGV_INSIDE_QUOTES! == TRUE (
        EXIT /B 1
      )
      SET PARSE_ARGV_END=TRUE
    ) ELSE IF NOT "%~2!PARSE_ARGV_INSIDE_QUOTES!" == " FALSE" (
      SET PARSE_ARGV_ARG=[%PARSE_ARGV_ARG:~1,-1%%~2]
      EXIT /B 0
    )
    IF NOT !PARSE_ARGV_INDEX! == 1 (
      SET /A ARGC = !ARGC! + 1
      SET ARG!ARGC!=%PARSE_ARGV_ARG:~1,-1%
      IF ^%PARSE_ARGV_ARG:~1,1% == ^" (
        SET ARG!ARGC!_=%PARSE_ARGV_ARG:~2,-2%
        SET ARG!ARGC!Q=%PARSE_ARGV_ARG:~1,-1%
      ) ELSE (
        SET ARG!ARGC!_=%PARSE_ARGV_ARG:~1,-1%
        SET ARG!ARGC!Q="%PARSE_ARGV_ARG:~1,-1%"
      )
      SET PARSE_ARGV_ARG=[]
      SET PARSE_ARGV_INSIDE_QUOTES=FALSE
    )
    EXIT /B 0

:getarg
  SET %2=!ARG%1!
  SET %2_=!ARG%1_!
  SET %2Q=!ARG%1Q!
  EXIT /B 0

:getargs
  SET %3=
  FOR /L %%I IN (%1,1,%2) DO (
    IF %%I == %1 (
      SET %3=!ARG%%I!
    ) ELSE (
      SET %3=!%3! !ARG%%I!
    )
  )
  EXIT /B 0


:end



