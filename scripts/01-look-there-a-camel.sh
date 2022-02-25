#!/bin/bash

set -eu

echo "Running scenario 01: Look there's a Camel"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1800 800 camel-01-normal
create_users_with_custom_build 9 camel-01-builds
create_custom_users camel-no-resources.yaml 150 camel-01-nores
create_custom_users camel-full.yaml 40 camel-01-full
create_custom_users camel-platform.yaml 1 camel-01-platform
