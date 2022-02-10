#!/bin/bash

set -eu

echo "Running scenario 04: Good cameleers share builds"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1000 0 camel-04-empty
create_standard_users 10 0 camel-04-full
create_standard_users 940 0 camel-04-nores
create_users_with_custom_build 50 camel-04-builds
inject_peak_workload camel-full.yaml 10 camel-04-full
inject_peak_workload camel-no-resources.yaml 940 camel-04-nores
