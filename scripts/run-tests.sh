#!/usr/bin/env bash

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NOCOLOR="\033[0m"

WEBSERVER_PORT=8080
CHROMEDRIVER_PORT=4444

# The current directory path
export CURRENT_DIR="${PWD}"

cd "$(dirname "$0")"

source "includes/_helpers.sh"

TEST_PATH="$1"

TEST_PATH=$(to_absolute "${TEST_PATH}")

if [ ! "${TEST_PATH}" ]; then
  echo -e " ${RED}[error]${NOCOLOR} Provide path to Tests. Ex:"
  echo -e " ${YELLOW}./scripts/run-tests web/modules/contrib/pathauto${NOCOLOR}"
  exit 1
fi

if [[ ! -e "${TEST_PATH}" ]]; then
  echo -e " ${RED}[error]${NOCOLOR} Incorrect directory or file path."
  exit 1
fi

extract_base_path() {
  local path="$1"
  local normalized_path=$(echo "$path" | sed 's#//*#/#g')
  local web_index=$(echo "$normalized_path" | awk -F'/' '{for(i=1;i<=NF;i++) if($i=="web" || $i=="docroot") print i;}' | head -n 1)
  if [ -n "$web_index" ]; then
    echo "$normalized_path" | cut -d'/' -f1-"$web_index"
  else
    echo "$normalized_path"
  fi
}

extract_module_name() {
  local path="$1"
  local normalized_path=$(echo "$path" | sed 's#//*#/#g')  # Normalize path
  local value=$(echo "$normalized_path" | awk -F'/' '{ for(i=1; i<=NF; i++) { if($i == "modules" && ($(i+1) == "custom" || $(i+1) == "contrib")) { print $(i+2); exit } } }')
  # Format the value: lowercase, remove underscores and hyphens, convert to title case
  value=$(echo "$value" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' )
  echo "$value"
}

WEB_PATH=$(extract_base_path "${TEST_PATH}")
PROJECT_PATH=$(realpath "${WEB_PATH}/../")
MODULE_NAME=$(extract_module_name "${TEST_PATH}")

echo -e "${GREEN}Running on ${OSTYPE}${NOCOLOR}"

# Install ChromeDriver based on OS.
installchromedriver() {
  CHROMEDRIVER=${PROJECT_PATH}/vendor/bin/chromedriver
  if [ -f "$CHROMEDRIVER" ]; then
    VERSION=$("${CHROMEDRIVER}" --version | awk '{ print $2 } ')
  fi
  CHROMEDRIVER_VERSION=$(curl -q -s https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_STABLE)

  if [[ ${VERSION} == ${CHROMEDRIVER_VERSION} ]]; then
    echo -e "${GREEN}ChromeDriver ${VERSION} available.${NOCOLOR}"
  else
    echo -e "${YELLOW}Installing ChromeDriver...${NOCOLOR}"
    case $OSTYPE in
      "linux-gnu"*)
        # Installs chromedriver for Linux 64 bit systems.
        curl https://storage.googleapis.com/chrome-for-testing-public/$CHROMEDRIVER_VERSION/linux64/chromedriver-linux64.zip -o chromedriver-linux64.zip -s
        unzip chromedriver-linux64.zip
        chmod +x chromedriver-linux64/chromedriver
        mv -f chromedriver-linux64/chromedriver ${PROJECT_PATH}/vendor/bin
        rm -rf chromedriver-linux64
        rm chromedriver-linux64.zip
        ;;
      "darwin"*)
        # Installs chromedriver for MacOS 64 bit systems.
        curl https://storage.googleapis.com/chrome-for-testing-public/$CHROMEDRIVER_VERSION/mac-x64/chromedriver-mac-x64.zip -o chromedriver-mac-x64.zip -s
        unzip chromedriver-mac-x64.zip
        chmod +x chromedriver-mac-x64/chromedriver
        mv -f chromedriver-mac-x64/chromedriver ${PROJECT_PATH}/vendor/bin
        rm -rf chromedriver-mac-x64
        rm chromedriver-mac-x64.zip
        ;;
    esac
  fi
}

# Start PHP's built-in http server on port "${WEBSERVER_PORT}".
runwebserver() {
  echo -e "${YELLOW}Starting PHP's built-in http server on "${WEBSERVER_PORT}".${NOCOLOR}"
  nohup ${PROJECT_PATH}/vendor/bin/drush runserver "${WEBSERVER_PORT}" &
  echo -e "${GREEN}Drush server started on port "${WEBSERVER_PORT}".${NOCOLOR}"
}

# Run ChromeDriver on port "${CHROMEDRIVER_PORT}".
runchromedriver() {
  echo -e "${YELLOW}Starting ChromeDriver on port "${CHROMEDRIVER_PORT}".${NOCOLOR}"
  nohup ${PROJECT_PATH}/vendor/bin/chromedriver --port="${CHROMEDRIVER_PORT}" &
  echo -e "${GREEN}Started ChromeDriver on port "${CHROMEDRIVER_PORT}".${NOCOLOR}"
}

# Kill any process on a linux GNU environment.
killProcessLinuxOs() {
  if command -v fuser &> /dev/null
    then
      fuser -k "${1}/tcp"
      echo -e "${YELLOW}Process killed on port $1 ${NOCOLOR}"
    else
      echo 'Please install fuser';
      exit 1
    fi
}

# Kill any process on a Darwin environment.
killProcessDarwinOs() {
  nohup kill -9 $(lsof -t -i:${1})
  echo -e "${YELLOW}Process killed on port $1 ${NOCOLOR}"
}

# Kill all the processes this script has started.
testExit() {
  if [ $1 -eq 0 ]
  then
    echo -e "${GREEN}${2}${NOCOLOR}"
  else
    echo -e "${RED}${2}${NOCOLOR}"
  fi

  # Kill the processes based on OS.
  case $OSTYPE in
    "linux-gnu"*)
      if [ ! "${AH_SITE_ENVIRONMENT}" = "ide" ]; then
        echo -e "${YELLOW}Stopping drush webserver.${NOCOLOR}"
        killProcessLinuxOs "${WEBSERVER_PORT}"
        echo -e "${YELLOW}Stopping chromedriver.${NOCOLOR}"
        killProcessLinuxOs "${CHROMEDRIVER_PORT}"
      else
        echo -e "${YELLOW}Stopping chromedriver.${NOCOLOR}"
        pkill chromedriver
      fi
      ;;
    "darwin"*)
      echo -e "${YELLOW}Stopping drush webserver.${NOCOLOR}"
      killProcessDarwinOs "${WEBSERVER_PORT}"
      echo -e "${YELLOW}Stopping chromedriver.${NOCOLOR}"
      killProcessDarwinOs "${CHROMEDRIVER_PORT}"
      ;;
  esac
  exit $1
}

# Switch case to handle macOS and Linux.
case $OSTYPE in
  "linux-gnu"*)
    if [ ! "${AH_SITE_ENVIRONMENT}" = "ide" ]; then
      if declare -a array=($(tail -n +2 /proc/net/tcp | cut -d":" -f"3"|cut -d" " -f"1")) &&
        for port in ${array[@]}; do echo $((0x$port)); done | grep "${WEBSERVER_PORT}" ; then
          echo -e "${RED}Port "${WEBSERVER_PORT}" is already occupied. Web server cannot start on port "${WEBSERVER_PORT}".${NOCOLOR}"
        else
          runwebserver
      fi
      if declare -a array=($(tail -n +2 /proc/net/tcp | cut -d":" -f"3"|cut -d" " -f"1")) &&
        for port in ${array[@]}; do echo $((0x$port)); done | grep "${CHROMEDRIVER_PORT}" ; then
          echo -e "${RED}Port "${CHROMEDRIVER_PORT}" is already occupied. ChromeDriver cannot run on port "${CHROMEDRIVER_PORT}". ${NOCOLOR}"
        else
          installchromedriver
          runchromedriver
      fi
    else
      nohup chromedriver --port=${CHROMEDRIVER_PORT} &
      echo -e "${GREEN}Started ChromeDriver on port "${CHROMEDRIVER_PORT}".${NOCOLOR}"
    fi
    ;;
  "darwin"*)
      if [ -z "$(lsof -t -i:"${WEBSERVER_PORT}")" ] ; then
        runwebserver
      else
        echo -e "${RED}Port "${WEBSERVER_PORT}" is already occupied. Web server cannot start on port "${WEBSERVER_PORT}". ${NOCOLOR}"
      fi
      if [ -z "$(lsof -t -i:"${CHROMEDRIVER_PORT}")" ] ; then
        installchromedriver
        runchromedriver
      else
        echo -e "${RED}Port "${CHROMEDRIVER_PORT}" is already occupied. ChromeDriver cannot run on port "${CHROMEDRIVER_PORT}". ${NOCOLOR}"
      fi
      ;;
esac

# Set SIMPLETEST_DB environment variable if it is not set already.
if [ -z "$(printenv SIMPLETEST_DB)" ] ; then
  export SIMPLETEST_DB=sqlite://localhost/drupal.sqlite
  echo -e "${GREEN}SIMPLETEST_DB environment variable is now set as: ${NOCOLOR}"
  printenv SIMPLETEST_DB
  echo -e "${YELLOW}If you are using MySQL or PostgreSQL, set the environment variable accordingly, e.g., mysql://drupal:drupal@127.0.0.1/drupal${NOCOLOR}"
fi

# Set SIMPLETEST_BASE_URL environment variable if it is not set already.
if [ -z "$(printenv SIMPLETEST_BASE_URL)" ] ; then
  export SIMPLETEST_BASE_URL=http://127.0.0.1:"${WEBSERVER_PORT}"
  echo -e "${GREEN}SIMPLETEST_BASE_URL environment variable is now set as: ${NOCOLOR}"
  printenv SIMPLETEST_BASE_URL
fi

# Set DTT_BASE_URL environment variable if it is not set already.
if [ -z "$(printenv DTT_BASE_URL)" ] ; then
  export DTT_BASE_URL=$SIMPLETEST_BASE_URL
  echo -e "${GREEN}DTT_BASE_URL environment variable is now set as: ${NOCOLOR}"
  printenv DTT_BASE_URL
fi

# Set MINK_DRIVER_ARGS_WEBDRIVER environment variable if it is not set already.
if [ -z "$(printenv MINK_DRIVER_ARGS_WEBDRIVER)" ] ; then
  export MINK_DRIVER_ARGS_WEBDRIVER='["chrome", {"chrome": {"switches": ["headless"]}}, "http://127.0.0.1:4444"]'
  echo -e "${GREEN}MINK_DRIVER_ARGS_WEBDRIVER environment variable is now set as: ${NOCOLOR}"
  printenv MINK_DRIVER_ARGS_WEBDRIVER
fi

# Set DTT_MINK_DRIVER_ARGS environment variable if it is not set already.
if [ -z "$(printenv DTT_MINK_DRIVER_ARGS)" ] ; then
  export DTT_MINK_DRIVER_ARGS=$MINK_DRIVER_ARGS_WEBDRIVER
  echo -e "${GREEN}DTT_MINK_DRIVER_ARGS environment variable is now set as: ${NOCOLOR}"
  printenv DTT_MINK_DRIVER_ARGS
fi

# Set SYMFONY_DEPRECATIONS_HELPER environment variable if it is not set already.
if [ -z "$(printenv SYMFONY_DEPRECATIONS_HELPER)" ] ; then
  export SYMFONY_DEPRECATIONS_HELPER=weak
  echo -e "${GREEN}SYMFONY_DEPRECATIONS_HELPER environment variable is now set as:${NOCOLOR}"
  printenv SYMFONY_DEPRECATIONS_HELPER
fi

# Run all automated PHPUnit tests.
# If --stop-on-failure is passed as an argument $1 will handle it.
echo -e "${YELLOW}Running phpunit tests for '${MODULE_NAME}' module.${NOCOLOR}"
COMPOSER_PROCESS_TIMEOUT=0 "${PROJECT_PATH}/vendor/bin/phpunit" -c "${WEB_PATH}/core" ${TEST_PATH}

# Terminate all the processes
if [ $? -ne 0 ] ;
then
  testExit 1 "PHP Tests have failed. Stopping further processing!"
else
  testExit 0 "All tests are passing. Well done!"
fi
