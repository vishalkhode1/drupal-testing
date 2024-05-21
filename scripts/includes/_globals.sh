#!/bin/bash

export INSTALLATION_PROFILE="${INSTALLATION_PROFILE:-minimal}"
export TEMPLATE="${TEMPLATE:-drupal}"
export DRUPAL_VERSION="${DRUPAL_VERSION:-11}"
export FORCE="${FORCE:-false}"

export DB_URL="${DB_NAME:-.default.sqlite}"