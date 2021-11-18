#!/bin/bash

set -eu

echo "Running scenario 03: The summit live workshop"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 2990 0 camel-03-nores
create_standard_users 10 0 camel-03-full
inject_peak_workload camel-no-resources.yaml 990 camel-03-nores
inject_peak_workload camel-full.yaml 10 camel-03-full
