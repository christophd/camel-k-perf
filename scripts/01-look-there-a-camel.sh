#!/bin/bash

set -eu

echo "Running scenario 01: Look there's a Camel"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1900 900 camel-01-normal
create_users_with_custom_build 9 camel-01-builds
create_custom_users camel-platform.yaml 1 camel-01-platform
create_custom_users camel-no-resources.yaml 80 camel-01-nores
create_custom_users camel-full.yaml 10 camel-01-full
