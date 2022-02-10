#!/bin/bash

set -eu

echo "Running scenario 05: The bad workshop"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1900 0 camel-05-empty
create_standard_users 100 0 camel-05-platform
inject_peak_workload camel-platform.yaml 100 camel-05-platform
