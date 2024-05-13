#!/bin/bash

CURRENT_DIR=$(PWD)

cd "$(dirname "$0")"
# Color codes definition.
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
NOCOLOR="\033[0m"
RED="\033[0;31m"
RED_BG="\033[41m"
WHITE="\033[1;37m"
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
UNDERLINE=$(tput smul)
NO_UNDERLINE=$(tput rmul)

if [ ! "${INSTALLATION_PROFILE}" ]; then
  # If not set, use default value
  INSTALLATION_PROFILE="minimal"
fi

# Displays the command help text.
display_help() {
    echo -e "Usage: $0 --{option}={value}"; echo>&2
    echo -e "${YELLOW}Examples:${NOCOLOR}"
    echo -e "  $0 --template=acquia \t Create a fresh new acquia/drupal-recommended-project."
    echo -e "  $0 --template=drupal \t Create a fresh new drupal/recommended-project."
    echo -e "  $0 --drupal=10 Downloads the latest Drupal 10 project."
    echo
    echo -e "${YELLOW}Options:${NOCOLOR}"
    echo -e "  --template[=TEMPLATE] \t Create a new project of given template. Allowed values [${GREEN}acquia${NOCOLOR} or ${GREEN}drupal${NOCOLOR}]. Default [${GREEN}acquia${NOCOLOR}]."
    echo -e "  --drupal[=DRUPAL_VERSION] \t Drupal version to download. Allowed values [${GREEN}9${NOCOLOR}, ${GREEN}10${NOCOLOR} or ${GREEN}11${NOCOLOR}]. Default [${GREEN}10${NOCOLOR}]."
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
    --template=|--drupal=) # Handle the case of an empty
      display_value_error $1
      exit 1
      ;;
    --template=?*)
      TEMPLATE=${1#*=} # Delete everything up to "=" and assign the remainder.
      ;;
    --drupal=?*)
      DRUPAL_VERSION=${1#*=} # Delete everything up to "=" and assign the remainder.
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

DIR=$1

if [ ! "${TEMPLATE}" ]; then
  TEMPLATE="acquia"
fi

if [ ! "${DRUPAL_VERSION}" ]; then
  DRUPAL_VERSION="10"
fi

validateTemplate
validateDrupalVersion

executeCommand() {
  printCommand "$1"
  eval "$1"
}

printCommand() {
  echo -e " ${GREEN}> $1${NOCOLOR}"
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
if [ ! "${DIR}" ]; then
  DIR="${CURRENT_DIR}/drupal${DRUPAL_VERSION}"
  echo -e " ${YELLOW}${BOLD}[warning] ${NOCOLOR}${NORMAL}No directory defined. Using directory '${CYAN}${UNDERLINE}${DIR}${NO_UNDERLINE}${NOCOLOR}' to create a new project."
fi

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

  rm -fr ${DIR}
  printHeading "Downloading a new '${PROJECT_TEMPLATE}'"
  executeCommand "composer create-project ${PROJECT_TEMPLATE}:${PROJECT_VERSION} ${DIR}"
  if [ "${TEMPLATE}" = "drupal" ]; then
    executeCommand "composer config minimum-stability dev -d ${DIR}"
    if [ "${DRUPAL_VERSION}" = "11" ]; then
      executeCommand "composer require drush/drush:^13 -d ${DIR} -W"
    else
      executeCommand "composer require drush/drush -d ${DIR} -W"
    fi
    executeCommand "composer config --no-plugins allow-plugins.cweagans/composer-patches true -d ${DIR}"
    executeCommand "composer require cweagans/composer-patches:^1 -d ${DIR}"
    executeCommand "composer config extra.enable-patching true -d ${DIR}"
  fi

  printHeading "Downloading development dependencies"
  executeCommand "composer require drupal/core-dev:${CORE_DEV_VERSION} -d ${DIR}"

  if [ "${TEMPLATE}" = "drupal" ]; then
    executeCommand "cp ../assets/example.gitignore ${DIR}/.gitignore"
  fi

  printHeading "Adding git to project"
  executeCommand "git -C ${DIR} init"
  executeCommand "git -C ${DIR} add ."
  executeCommand "git -C ${DIR} commit -m 'Initial source code committed.'"
  exit 0
}

installDrupal() {
  printComment "Generating Hash salt"
  printCommand "php ./scripts/hash_generator.php 55"
  hash_salt=$(php ./hash_generator.php 55)

  printComment "Generating settings.php"

  db_settings=$(<../assets/settings.php.patch)
  db_name="${DIR}/.default.sqlite"

  if [ "${TEMPLATE}" = "drupal" ]; then
      executeCommand "cp ${DIR}/web/sites/default/default.settings.php ${DIR}/web/sites/default/settings.php"
      executeCommand "mkdir -p ${DIR}/config/default"
  fi
  case $OSTYPE in
    "linux-gnu"*)
      sed -i "s/\$settings\['hash_salt'\] = '';/\$settings\['hash_salt'\] = '$hash_salt';/" ${DIR}/web/sites/default/settings.php
      db_settings=$(echo "$db_settings" | sed "s#'database' => '',/'database' => '$db_name',#")
      ;;
    "darwin"*)
      sed -i '' "s/\$settings\['hash_salt'\] = '';/\$settings\['hash_salt'\] = '$hash_salt';/" ${DIR}/web/sites/default/settings.php
      db_settings=$(echo "$db_settings" | sed -e "s#'database' => '',#'database' => '$db_name',#")
      ;;
  esac
  echo -e "\n$db_settings" >> ${DIR}/web/sites/default/settings.php
  printComment "Added Hash salt & db settings in settings.php"
  printHeading "Installing Site"
  executeCommand "${DIR}/vendor/bin/drush site:install ${INSTALLATION_PROFILE} --account-pass=admin --yes"
}

#downloadDrupal
installDrupal
#addModules
