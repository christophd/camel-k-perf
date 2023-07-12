#!/bin/bash

set -eu

echo "Running scenario 01: Look there's a Camel"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1800 1800 camel-01-normal
create_custom_users_no_install camel-build-template.yaml 9 camel-01-builds
create_custom_users_no_install camel-no-resources.yaml 150 camel-01-nores
create_custom_users_no_install camel-full.yaml 40 camel-01-full
create_custom_users_no_install camel-platform.yaml 1 camel-01-platform
