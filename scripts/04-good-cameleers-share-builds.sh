#!/bin/bash

set -eu

echo "Running scenario 04: Good Camel riders share builds"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1400 1400 camel-04-normal

create_custom_users camel-no-resources.yaml 550 camel-04-nores
create_custom_users camel-build-template.yaml 50 camel-04-builds
