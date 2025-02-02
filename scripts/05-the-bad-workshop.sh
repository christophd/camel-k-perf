#!/bin/bash

set -eu

echo "Running scenario 05: The bad workshop"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1900 1900 camel-05-normal
create_standard_users_no_install 100 0 camel-05-platform

sleep 120s

inject_peak_workload camel-platform.yaml 100 5 camel-05-platform
