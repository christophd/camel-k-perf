#!/bin/bash

set -eu

echo "Running scenario 03: The summit live workshop"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 2000 0 camel-03-nores
inject_peak_workload camel-no-resources.yaml 600 camel-03-nores
