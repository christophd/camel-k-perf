#!/bin/bash

set -eu

echo "Running scenario 04: Good cameleers share builds"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1400 1400 camel-04-normal
create_standard_users 550 0 camel-04-nores

sleep 120s

inject_peak_workload camel-no-resources.yaml 550 50 camel-04-nores
create_users_with_custom_build 50 camel-04-builds
