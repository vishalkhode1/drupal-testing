#!/bin/bash

CURRENT_DIR=${PWD}

# Color codes definition.
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
NOCOLOR="\033[0m"
RED="\033[0;31m"
RED_BG="\033[41m"
GREEN_BG='\033[42m'
WHITE="\033[1;37m"

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
UNDERLINE=$(tput smul)
NO_UNDERLINE=$(tput rmul)

source ${CURRENT_DIR}/.config.sh
source ${CURRENT_DIR}/scripts/helpers.sh

# Displays the command help text.
display_help() {
    echo -e "Usage: $0 --{option}={value}"; echo>&2
    echo -e "${YELLOW}Examples:${NOCOLOR}"
    echo -e "  $0 --template=acquia \t Create a fresh new acquia/drupal-recommended-project."
    echo -e "  $0 --template=drupal \t Create a fresh new drupal/recommended-project."
    echo -e "  $0 --drupal=10 \t Downloads the latest Drupal 10 project."
    echo -e "  $0 --force \t\t Forcefully setup the project by deleting project directory (If already exists)."
    echo
    echo -e "${YELLOW}Options:${NOCOLOR}"
    echo -e "  --template[=TEMPLATE] \t Create a new project of given template. Allowed values [${GREEN}acquia${NOCOLOR} or ${GREEN}drupal${NOCOLOR}]. Default [${GREEN}drupal${NOCOLOR}]."
    echo -e "  --drupal[=DRUPAL_VERSION] \t Drupal version to download. Allowed values [${GREEN}9${NOCOLOR}, ${GREEN}10${NOCOLOR} or ${GREEN}11${NOCOLOR}]. Default [${GREEN}11${NOCOLOR}]."
    echo -e "  --force \t\t\t Delete the project directory, If already exist."
    echo
}

validateTemplate() {
  if [ "${TEMPLATE}" != "acquia" ] && [ "${TEMPLATE}" != "drupal" ]; then
    echo -e " ${RED}${BOLD}[error]${NORMAL}${NOCOLOR} Invalid template. Allowed template: '${GREEN}acquia${NOCOLOR}' or '${GREEN}drupal${NOCOLOR}'."
    exit 1
  fi
}

validateDrupalVersion() {
  if [ "${DRUPAL_VERSION}" != "9" ] && [ "${DRUPAL_VERSION}" != "10" ] && [ "${DRUPAL_VERSION}" != "11" ]; then
    echo -e " ${RED}${BOLD}[error]${NORMAL}${NOCOLOR} Invalid Drupal version. Allowed versions: ${GREEN}9${NOCOLOR}, ${GREEN}10${NOCOLOR} or ${GREEN}11${NOCOLOR}."
    exit 1
  fi
}
# Displays non empty option value error
display_value_error() {
  echo -e "${RED_BG}${WHITE}ERROR: Option: $1 requires a non-empty option value.${NOCOLOR}\n"
  display_help
  exit 1
}

# Displays non empty option value error
display_empty_value_error() {
  echo -e "${RED_BG}${WHITE}ERROR: Option: $1 doesn't accept any value.${NOCOLOR}\n"
  display_help
  exit 1
}

# Parse all options given to command.
while :; do
  case $1 in
    --template)
      if [[ $2 == -* ]]; then
        display_value_error $1
        exit 1
      fi
      if [ $2 ]; then
        TEMPLATE=$2
        shift
      else
        display_value_error $1
        exit 1
      fi
      ;;
    --force)
      FORCE=true
      ;;
    --drupal)
      if [[ $2 == -* ]]; then
        display_value_error $1
        exit 1
      fi
      if [ $2 ]; then
        DRUPAL_VERSION=$2
        shift
      else
        display_value_error $1
        exit 1
      fi
      ;;
    --template=|--drupal=|--force=) # Handle the case of an empty
      display_value_error $1
      exit 1
      ;;
    --template=?*)
      TEMPLATE=${1#*=} # Delete everything up to "=" and assign the remainder.
      ;;
    --drupal=?*)
      DRUPAL_VERSION=${1#*=} # Delete everything up to "=" and assign the remainder.
      ;;
    --force=?*)
      force_opt=${1#*=} # Delete everything up to "=" and assign the remainder.
      display_empty_value_error "--force"
      exit 1
      ;;
    --help)
      display_help
      exit 0
      ;;
    --) # End of all options.
      shift
      break;;
    -?*)
      echo -e "${RED_BG}${WHITE}ERROR: Unknown option: $1${NOCOLOR}"
      echo
      display_help
      exit 1
      ;;
    *) # Default case: No more options, so break out of the loop.
    break
  esac
  shift
done

if [ ! -z "$1" ]; then
  PROJECT_DIR=$1
fi

if [ ! "${TEMPLATE}" ]; then
  TEMPLATE="acquia"
fi

if [ ! "${DRUPAL_VERSION}" ]; then
  DRUPAL_VERSION="10"
fi

# Function to validate requirements
validate_requirements() {
  # Initialize flag to track failures
  fail_flag=0

  php_required=("8.1" "8.2")
  php_sqlite_required="3.26"
  if [ "${DRUPAL_VERSION}" = "11" ]; then
    php_required=("8.3")
    php_sqlite_required="3.45"
  elif [ "${DRUPAL_VERSION}" = "10" ]; then
    php_required=("8.1" "8.2" "8.3")
  fi

  # Convert php_required array to a string
  php_required_string=$(IFS=, ; echo "${php_required[*]}")
  php_required_string=$(echo $php_required_string | sed 's/,/ or /g')

  # Check PHP version
  php_version=$(php -r 'echo PHP_VERSION;')
  php_status="${RED}Error${NOCOLOR}"
  for required_version in "${php_required[@]}"; do
    if [[ "$php_version" == "$required_version"* ]]; then
      php_status="${GREEN}OK${NOCOLOR}"
      break
    fi
  done

  if [[ "$php_status" == "${RED}Error${NOCOLOR}" ]]; then
    fail_flag=1
  fi

  # Check for PHP SQLite library version
  php_sqlite_version=$(php -r 'echo SQLite3::version()["versionString"];')
  php_sqlite_check=$(echo -e "$php_sqlite_version\n$php_sqlite_required" | sort -V | head -n1)

  if [[ "$php_sqlite_check" != "$php_sqlite_required" ]]; then
    php_sqlite_status="${RED}Error${NOCOLOR}"
    fail_flag=1
  else
    php_sqlite_status="${GREEN}OK${NOCOLOR}"
  fi

  # Check if Composer is installed and version
  if composer_version=$(composer --version 2>&1); then
    composer_version=$(echo $composer_version | awk '{print $3}')
    composer_required="2"
    composer_check=$(echo -e "$composer_version\n$composer_required" | sort -V | head -n1)

    if [[ "$composer_check" != "$composer_required" ]]; then
      composer_status="${RED}Error${NOCOLOR}"
      fail_flag=1
    else
      composer_status="${GREEN}OK${NOCOLOR}"
    fi
  else
    composer_version="Not installed${NOCOLOR}"
    composer_status="${RED}Error${NOCOLOR}"
    fail_flag=1
  fi

  # Check Git installation
  git_version=$(git --version 2>/dev/null)
  if [ $? -ne 0 ]; then
    git_status="${RED}Error${NOCOLOR}"
    git_version="Not installed"
    fail_flag=1
  else
    git_status="${GREEN}OK${NOCOLOR}"
    git_version=$(echo "$git_version" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
  fi

  # Display results in tabular format
  echo " -------------------------------------------------------------------"
  # Display results in tabular format
  echo -e " ${GREEN}Requirement${NOCOLOR}           | ${GREEN}Status${NOCOLOR} | ${GREEN}Required Version${NOCOLOR} | ${GREEN}Current Version${NOCOLOR}"
  echo " -------------------------------------------------------------------"
  echo -e " PHP Version           | $php_status\t| $php_required_string\t\t| $php_version"
  echo -e " PHP SQLite Library    | $php_sqlite_status\t| >=$php_sqlite_required\t| $php_sqlite_version"
  echo -e " Composer              | $composer_status\t| >=$composer_required\t\t| $composer_version"
  echo -e " Git                   | $git_status\t| Any\t\t| $git_version"
  echo " ------------------------------------------------------------------"

  # Exit with status code 1 if any requirement failed
  if [[ $fail_flag -eq 1 ]]; then
    echo ""
    echo -e " ${RED_BG}${WHITE}[error]${NOCOLOR} Please fix above requirement errors and re-run command."
    echo ""
    exit 1
  else
    echo -e " ${GREEN_BG}${WHITE}[success]${NOCOLOR} All OK."
  fi
}

executeCommand() {
  printCommand "$1"
  eval "$1"
}

printCommand() {
  echo -e " ${YELLOW}> $1${NOCOLOR}"
}

printHeading() {
  heading="$1:"
  char_count=$(echo -e "${heading}" | wc -m)
  char_count=$((char_count - 1))
  echo -e "\n ${GREEN}${heading}${NOCOLOR}"
  s=$(printf "%-${char_count}s" "-")
  echo " ${s// /-}"
}

printComment() {
  echo -e "\n ${YELLOW}// $1${NOCOLOR}\n"
}

validateTemplate
validateDrupalVersion
printComment "Validating Drupal requirements"
validate_requirements

#if [ ! "${PROJECT_DIR}" ]; then
#  PROJECT_DIR="${CURRENT_DIR}/drupal${DRUPAL_VERSION}"
#  echo -e " ${YELLOW}${BOLD}[warning] ${NOCOLOR}${NORMAL}No directory defined. Using directory '${CYAN}${UNDERLINE}${PROJECT_DIR}${NO_UNDERLINE}${NOCOLOR}' to create a new project."
#else
  # Convert to absolute path if it's relative
  PROJECT_DIR=$(to_absolute "${PROJECT_DIR}")
#fi

cd "$(dirname "$0")"

downloadDrupal() {
  if [ "${DRUPAL_VERSION}" = "9" ]; then
    PROJECT_VERSION="^9"
    CORE_DEV_VERSION="^9"
  elif [ "${DRUPAL_VERSION}" = "10" ]; then
    PROJECT_VERSION="^10"
    CORE_DEV_VERSION="^10"
  else
    PROJECT_VERSION="11.0.0-alpha1"
    CORE_DEV_VERSION="^11"
  fi

  if [ "${TEMPLATE}" = "acquia" ]; then
    PROJECT_TEMPLATE="acquia/drupal-recommended-project"
    if [ "${DRUPAL_VERSION}" = "9" ]; then
      PROJECT_VERSION="^1"
    elif [ "${DRUPAL_VERSION}" = "10" ]; then
      PROJECT_VERSION="^2"
    else
      PROJECT_VERSION="dev-drupal11"
    fi
  else
    PROJECT_TEMPLATE="drupal/recommended-project"
  fi

  if [[ -d "${PROJECT_DIR}" ]]; then
    if [ $FORCE != "true" ]; then
      echo -e " ${RED}${BOLD}[error] ${NOCOLOR}${NORMAL}The project at path: '${CYAN}${UNDERLINE}${PROJECT_DIR}${NO_UNDERLINE}${NOCOLOR}' already exist."
      echo -e " Re-run the command passing ${YELLOW}--force${NOCOLOR} option."
      exit 1
    else
      printHeading "Deleting the project directory ${PROJECT_DIR}"
      executeCommand "chmod -R 777 ${PROJECT_DIR}"
      executeCommand "rm -fr ${PROJECT_DIR}"
    fi
  fi

  printHeading "Downloading a new '${PROJECT_TEMPLATE}'"
  executeCommand "composer create-project ${PROJECT_TEMPLATE}:${PROJECT_VERSION} ${PROJECT_DIR}"
  if [ "${TEMPLATE}" = "drupal" ]; then
    executeCommand "composer config minimum-stability dev -d ${PROJECT_DIR}"
    if [ "${DRUPAL_VERSION}" = "11" ]; then
      executeCommand "composer require drush/drush:^13 -d ${PROJECT_DIR} -W"
    else
      executeCommand "composer require drush/drush -d ${PROJECT_DIR} -W"
    fi
    executeCommand "composer config --no-plugins allow-plugins.cweagans/composer-patches true -d ${PROJECT_DIR}"
    executeCommand "composer require cweagans/composer-patches:^1 -d ${PROJECT_DIR}"
    executeCommand "composer config extra.enable-patching true -d ${PROJECT_DIR}"
  fi

  printHeading "Downloading development dependencies"
  executeCommand "composer require drupal/core-dev:${CORE_DEV_VERSION} -d ${PROJECT_DIR} --dev -W"

  if [ "${TEMPLATE}" = "drupal" ]; then
    executeCommand "cp ../assets/example.gitignore ${PROJECT_DIR}/.gitignore"
  fi
}

installDrupal() {
  printComment "Generating Hash salt"
  printCommand "php ./scripts/hash_generator.php 55"
  hash_salt=$(php ./hash_generator.php 55)

  printComment "Generating settings.php"

  db_settings=$(<../assets/settings.php.patch)
  db_name="${PROJECT_DIR}/.default.sqlite"

  if [ "${TEMPLATE}" = "drupal" ]; then
      executeCommand "cp ${PROJECT_DIR}/web/sites/default/default.settings.php ${PROJECT_DIR}/web/sites/default/settings.php"
      executeCommand "mkdir -p ${PROJECT_DIR}/config/default"
  fi
  case $OSTYPE in
    "linux-gnu"*)
      sed -i "s/\$settings\['hash_salt'\] = '';/\$settings\['hash_salt'\] = '$hash_salt';/" ${PROJECT_DIR}/web/sites/default/settings.php
      db_settings=$(echo "$db_settings" | sed "s|'database' => '',|'database' => '$db_name',|")
      ;;
    "darwin"*)
      sed -i '' "s/\$settings\['hash_salt'\] = '';/\$settings\['hash_salt'\] = '$hash_salt';/" ${PROJECT_DIR}/web/sites/default/settings.php
      db_settings=$(echo "$db_settings" | sed -e "s#'database' => '',#'database' => '$db_name',#")
      ;;
  esac
  echo -e "\n$db_settings" >> ${PROJECT_DIR}/web/sites/default/settings.php
  printComment "Added Hash salt & db settings in settings.php"
  printHeading "Installing Site"
  executeCommand "${PROJECT_DIR}/vendor/bin/drush site:install ${INSTALLATION_PROFILE} --account-pass=admin --yes"
}

addingGitToProject() {
  printHeading "Adding git to project"
  executeCommand "git -C ${PROJECT_DIR} init"
  executeCommand "git -C ${PROJECT_DIR} add ."
  executeCommand "git -C ${PROJECT_DIR} commit -m 'Initial source code committed.'"
}

downloadDrupal
installDrupal
addingGitToProject

echo ""
echo -e " ${GREEN_BG}${WHITE} Your Drupal ${DRUPAL_VERSION} project has been successfully created.${NOCOLOR}"
echo ""
exit 0